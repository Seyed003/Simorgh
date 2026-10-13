// Package xray adds an "xray" outbound to sing-box: one Xray-core outbound
// (for transports sing-box lacks, such as XHTTP and mKCP) that sing-box
// routes to like any other proxy. Xray only encodes the traffic; every
// socket it opens is dialed by sing-box, so Android's VpnService protection,
// interface binding on Windows and sing-box's DNS all apply to it.
//
// scripts/build_libbox.sh and scripts/build_core_windows.sh copy this
// package into the sing-box source tree as protocol/xray.
package xray

import (
	"bytes"
	"context"
	stdjson "encoding/json"
	"net"
	"sync"
	"sync/atomic"
	"syscall"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/adapter/outbound"
	"github.com/sagernet/sing-box/common/dialer"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	E "github.com/sagernet/sing/common/exceptions"
	"github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/common/logger"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
	"github.com/sagernet/sing/service"

	xnet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/infra/conf/serial"
	"github.com/xtls/xray-core/transport/internet"

	// Outbound protocols and transports an Xray share link can use.
	_ "github.com/xtls/xray-core/app/dispatcher"
	_ "github.com/xtls/xray-core/app/proxyman/inbound"
	_ "github.com/xtls/xray-core/app/proxyman/outbound"
	_ "github.com/xtls/xray-core/proxy/freedom"
	_ "github.com/xtls/xray-core/proxy/shadowsocks"
	_ "github.com/xtls/xray-core/proxy/trojan"
	_ "github.com/xtls/xray-core/proxy/vless/outbound"
	_ "github.com/xtls/xray-core/proxy/vmess/outbound"
	_ "github.com/xtls/xray-core/transport/internet/grpc"
	_ "github.com/xtls/xray-core/transport/internet/httpupgrade"
	_ "github.com/xtls/xray-core/transport/internet/kcp"
	_ "github.com/xtls/xray-core/transport/internet/reality"
	_ "github.com/xtls/xray-core/transport/internet/splithttp"
	_ "github.com/xtls/xray-core/transport/internet/tcp"
	_ "github.com/xtls/xray-core/transport/internet/tls"
	_ "github.com/xtls/xray-core/transport/internet/udp"
	_ "github.com/xtls/xray-core/transport/internet/websocket"
)

const Type = "xray"

// Options of an "xray" outbound: sing-box dial fields plus one Xray
// outbound object (protocol, settings, streamSettings, mux) and, optionally,
// Xray's TLS ClientHello fragmentation (a freedom "fragment" object).
type Options struct {
	option.DialerOptions
	Xray     json.RawMessage `json:"xray"`
	Fragment json.RawMessage `json:"fragment,omitempty"`
}

func RegisterOutbound(registry *outbound.Registry) {
	outbound.Register[Options](registry, Type, NewOutbound)
}

var _ adapter.Outbound = (*Outbound)(nil)

type Outbound struct {
	outbound.Adapter
	logger   logger.ContextLogger
	owner    *owner
	instance *core.Instance
}

func NewOutbound(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, options Options) (adapter.Outbound, error) {
	if len(options.Xray) == 0 {
		return nil, E.New("missing xray outbound")
	}
	var outboundConfig map[string]any
	if err := stdjson.Unmarshal(options.Xray, &outboundConfig); err != nil {
		return nil, E.Cause(err, "parse xray outbound")
	}
	outboundConfig["tag"] = "proxy"
	outbounds := []any{outboundConfig}
	if len(options.Fragment) > 0 {
		var fragment any
		if err := stdjson.Unmarshal(options.Fragment, &fragment); err != nil {
			return nil, E.Cause(err, "parse xray fragment")
		}
		streamSettings, _ := outboundConfig["streamSettings"].(map[string]any)
		if streamSettings == nil {
			streamSettings = map[string]any{}
			outboundConfig["streamSettings"] = streamSettings
		}
		sockopt, _ := streamSettings["sockopt"].(map[string]any)
		if sockopt == nil {
			sockopt = map[string]any{}
			streamSettings["sockopt"] = sockopt
		}
		sockopt["dialerProxy"] = "fragment"
		outbounds = append(outbounds, map[string]any{
			"tag":      "fragment",
			"protocol": "freedom",
			"settings": map[string]any{"fragment": fragment},
		})
	}
	content, err := stdjson.Marshal(map[string]any{
		"log":       map[string]any{"loglevel": "none"},
		"outbounds": outbounds,
	})
	if err != nil {
		return nil, err
	}
	config, err := serial.LoadJSONConfig(bytes.NewReader(content))
	if err != nil {
		return nil, E.Cause(err, "load xray outbound")
	}
	instance, err := core.New(config)
	if err != nil {
		return nil, E.Cause(err, "create xray instance")
	}
	outboundDialer, err := dialer.New(ctx, options.DialerOptions, true)
	if err != nil {
		return nil, err
	}
	return &Outbound{
		Adapter:  outbound.NewAdapterWithDialerOptions(Type, tag, []string{N.NetworkTCP, N.NetworkUDP}, options.DialerOptions),
		logger:   logger,
		owner:    &owner{ctx: ctx, dialer: outboundDialer},
		instance: instance,
	}, nil
}

func (h *Outbound) Start(stage adapter.StartStage, scope *adapter.Scope) error {
	if stage != adapter.StartStateStart {
		return nil
	}
	owners.Store(h.instance, h.owner)
	latestOwner.Store(h.owner)
	scope.Add(func() error {
		owners.Delete(h.instance)
		latestOwner.CompareAndSwap(h.owner, nil)
		return h.instance.Close()
	})
	return h.instance.Start()
}

func (h *Outbound) DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error) {
	ctx, metadata := adapter.ExtendContext(ctx)
	metadata.Outbound = h.Tag()
	metadata.Destination = destination
	switch N.NetworkName(network) {
	case N.NetworkTCP:
		h.logger.InfoContext(ctx, "outbound connection to ", destination)
		// The connection outlives the dial; Xray must not see the dial
		// timeout as the end of the session.
		return core.Dial(context.WithoutCancel(ctx), h.instance, toDestination(xnet.Network_TCP, destination))
	case N.NetworkUDP:
		h.logger.InfoContext(ctx, "outbound packet connection to ", destination)
		packetConn, err := core.DialUDP(context.WithoutCancel(ctx), h.instance)
		if err != nil {
			return nil, err
		}
		return &boundPacketConn{PacketConn: packetConn, destination: destination.UDPAddr()}, nil
	default:
		return nil, E.Extend(N.ErrUnknownNetwork, network)
	}
}

func (h *Outbound) ListenPacket(ctx context.Context, destination M.Socksaddr) (net.PacketConn, error) {
	ctx, metadata := adapter.ExtendContext(ctx)
	metadata.Outbound = h.Tag()
	metadata.Destination = destination
	h.logger.InfoContext(ctx, "outbound packet connection to ", destination)
	return core.DialUDP(context.WithoutCancel(ctx), h.instance)
}

func toDestination(network xnet.Network, destination M.Socksaddr) xnet.Destination {
	var address xnet.Address
	if destination.IsFqdn() {
		address = xnet.DomainAddress(destination.Fqdn)
	} else {
		address = xnet.IPAddress(destination.Addr.AsSlice())
	}
	return xnet.Destination{Network: network, Address: address, Port: xnet.Port(destination.Port)}
}

// boundPacketConn is a "connected" UDP conn over Xray's packet conn.
type boundPacketConn struct {
	net.PacketConn
	destination *net.UDPAddr
}

func (c *boundPacketConn) Read(b []byte) (int, error) {
	n, _, err := c.ReadFrom(b)
	return n, err
}

func (c *boundPacketConn) Write(b []byte) (int, error) {
	return c.WriteTo(b, c.destination)
}

func (c *boundPacketConn) RemoteAddr() net.Addr {
	return c.destination
}

// Xray's sockets are opened by the sing-box outbound that owns the Xray
// instance in the dial context.
var (
	owners sync.Map // *core.Instance -> *owner
	// For the rare dial whose context lost the instance.
	latestOwner atomic.Pointer[owner]
)

type owner struct {
	ctx    context.Context
	dialer N.Dialer
}

// listenUDP opens an unconnected UDP socket the way Xray's own system dialer
// does (mKCP and finalmask need one), protected/bound like sing-box's.
func (o *owner) listenUDP(ctx context.Context, destination M.Socksaddr) (net.Conn, error) {
	if destination.IsFqdn() {
		// Resolve with the outbound's resolver; connecting a UDP socket
		// sends nothing.
		probe, err := o.dialer.DialContext(ctx, N.NetworkUDP, destination)
		if err != nil {
			return nil, err
		}
		destination = M.SocksaddrFromNet(probe.RemoteAddr()).Unwrap()
		probe.Close()
	}
	var listenConfig net.ListenConfig
	if networkManager := service.FromContext[adapter.NetworkManager](o.ctx); networkManager != nil {
		if bind := networkManager.AutoDetectInterfaceFunc(); bind != nil {
			listenConfig.Control = func(network, _ string, conn syscall.RawConn) error {
				return bind(network, destination.String(), conn)
			}
		}
	}
	network := "udp4"
	if destination.IsIPv6() {
		network = "udp6"
	}
	packetConn, err := listenConfig.ListenPacket(ctx, network, "")
	if err != nil {
		return nil, err
	}
	return &internet.PacketConnWrapper{Conn: packetConn, Dest: destination.UDPAddr()}, nil
}

type systemDialer struct{}

func (systemDialer) Dial(ctx context.Context, _ xnet.Address, destination xnet.Destination, _ *internet.SocketConfig) (net.Conn, error) {
	var o *owner
	if instance := core.FromContext(ctx); instance != nil {
		if found, ok := owners.Load(instance); ok {
			o = found.(*owner)
		}
	}
	if o == nil {
		o = latestOwner.Load()
	}
	if o == nil {
		return nil, E.New("xray: dial outside of a sing-box outbound")
	}
	address := M.ParseSocksaddrHostPort(destination.Address.String(), uint16(destination.Port))
	if destination.Network == xnet.Network_UDP {
		return o.listenUDP(ctx, address)
	}
	return o.dialer.DialContext(ctx, N.NetworkTCP, address)
}

func (systemDialer) DestIpAddress() net.IP {
	return nil
}

func init() {
	internet.UseAlternativeSystemDialer(systemDialer{})
}
