import 'dart:convert';

import 'protocols/openconnect.dart';
import 'protocols/xray_outbound.dart';

/// Protocols the parser understands. WireGuard, OpenVPN and Cisco
/// AnyConnect are sing-box endpoints, every other protocol an outbound.
enum ProxyProtocol {
  vmess('VMess', 'vmess'),
  vless('VLESS', 'vless'),
  trojan('Trojan', 'trojan'),
  shadowsocks('Shadowsocks', 'shadowsocks'),
  hysteria2('Hysteria2', 'hysteria2'),
  hysteria('Hysteria', 'hysteria'),
  tuic('TUIC', 'tuic'),
  wireguard('WireGuard', 'wireguard'),
  ssh('SSH', 'ssh'),
  anytls('AnyTLS', 'anytls'),
  socks('SOCKS', 'socks'),
  openvpn('OpenVPN', 'openvpn-client'),
  openconnect('Cisco AnyConnect', 'openconnect'),

  /// An HTTP CONNECT proxy; only ever the first hop of a chain (OpenVPN
  /// profiles with `http-proxy`).
  http('HTTP proxy', 'http');

  const ProxyProtocol(this.displayName, this.singBoxType);

  final String displayName;

  /// The `type` value sing-box uses for this protocol.
  final String singBoxType;

  bool get isEndpoint => const {
    ProxyProtocol.wireguard,
    ProxyProtocol.openvpn,
    ProxyProtocol.openconnect,
  }.contains(this);

  /// Has to sign in to the server before it carries any traffic, which
  /// takes a few seconds after the core starts.
  bool get connectsFirst =>
      this == ProxyProtocol.openvpn || this == ProxyProtocol.openconnect;

  /// Signs in with a username and password ([ProxyConfig.needsLogin]).
  bool get hasLogin =>
      this == ProxyProtocol.openvpn || this == ProxyProtocol.openconnect;

  static ProxyProtocol? fromSingBoxType(String? type) {
    for (final p in values) {
      if (p.singBoxType == type) return p;
    }
    return null;
  }
}

/// One proxy server, already translated to sing-box JSON.
class ProxyConfig {
  const ProxyConfig({
    required this.protocol,
    required this.name,
    required this.server,
    required this.port,
    required this.outbound,
    this.link,
    this.via,
  });

  final ProxyProtocol protocol;

  /// Human readable remark (URL fragment / `ps` / sing-box tag).
  final String name;
  final String server;
  final int port;

  /// sing-box outbound (or endpoint for WireGuard) without a `tag`.
  final Map<String, Object?> outbound;

  /// Original share link when the config was imported from one.
  final String? link;

  /// The server this one is reached through (a chain): e.g. a server
  /// inside Iran that still reaches abroad when the international internet
  /// is cut.
  final ProxyConfig? via;

  /// A copy reached through [first] (or directly, when `null`).
  ProxyConfig chainedVia(ProxyConfig? first) => ProxyConfig(
    protocol: protocol,
    name: name,
    server: server,
    port: port,
    outbound: outbound,
    link: link,
    via: first,
  );

  /// Short transport/security summary for list tiles, e.g. `ws · tls`.
  String get summary {
    if (protocol == ProxyProtocol.openvpn) {
      final wrap = (outbound['tls'] as Map?)?['control_wrap'] as Map?;
      return [
        ?(outbound['network'] as String?),
        ?(wrap?['type'] as String?)?.replaceAll('_', '-'),
      ].join(' · ');
    }
    if (outbound.isXray) {
      return [?outbound.xrayNetwork, ?outbound.xraySecurity].join(' · ');
    }
    final parts = <String>[];
    final transport = outbound['transport'];
    if (transport is Map && transport['type'] is String) {
      parts.add(transport['type'] as String);
    }
    final tls = outbound['tls'];
    if (tls is Map && tls['enabled'] == true) {
      final reality = tls['reality'];
      parts.add(
        reality is Map && reality['enabled'] == true ? 'reality' : 'tls',
      );
    }
    final flow = outbound['flow'];
    if (flow is String && flow.isNotEmpty) parts.add('vision');
    return parts.join(' · ');
  }

  /// An OpenVPN or Cisco config still waiting for its username and
  /// password: the profile asks for them but did not carry them.
  bool get needsLogin {
    if (!protocol.hasLogin || !outbound.containsKey('username')) return false;
    final username = outbound['username'];
    return username is! String || username.isEmpty;
  }

  String get username => (outbound['username'] as String?) ?? '';

  /// A copy that signs in as [username].
  ProxyConfig withLogin(String username, String password) {
    final updated = {...outbound, 'username': username, 'password': password};
    return ProxyConfig(
      protocol: protocol,
      name: name,
      server: server,
      port: port,
      outbound: updated,
      link: protocol == ProxyProtocol.openconnect
          ? openConnectLink(updated, name)
          : link,
      via: via,
    );
  }

  /// Does not check who the server is, so whoever sits in the middle can
  /// read the traffic: TLS without the certificate check (`insecure` /
  /// `allowInsecure`), or SSH without the server's host key. A chain is as
  /// weak as its weakest hop.
  bool get isInsecure {
    final tls = outbound['tls'];
    if (tls is Map && tls['insecure'] == true) return true;
    if (outbound['type'] == 'ssh') {
      final hostKey = outbound['host_key'];
      if (hostKey is! List || hostKey.isEmpty) return true;
    }
    return via?.isInsecure ?? false;
  }

  /// The stored outbound really is the protocol the config is shown as,
  /// down every chain hop. Our parsers always make it so; a hand-made file
  /// (a backup) could instead hide, say, a `direct` outbound behind a
  /// "VLESS" name, so traffic would skip the tunnel while the app shows
  /// it connected.
  bool get isConsistent {
    final type = outbound['type'];
    final matches = type == xrayOutboundType
        ? _xrayProtocols.contains(protocol)
        : type is String && ProxyProtocol.fromSingBoxType(type) == protocol;
    return matches && (via?.isConsistent ?? true);
  }

  static const _xrayProtocols = {
    ProxyProtocol.vless,
    ProxyProtocol.vmess,
    ProxyProtocol.trojan,
    ProxyProtocol.shadowsocks,
  };

  /// Host name the server is reached by in TLS (SNI), else the address.
  String get tlsHost {
    if (outbound.isXray) {
      final sni = outbound.xrayServerName;
      return sni != null && sni.isNotEmpty ? sni : server;
    }
    final tls = outbound['tls'];
    final sni = tls is Map ? tls['server_name'] : null;
    return sni is String && sni.isNotEmpty ? sni : server;
  }

  /// Looks like a config served through a CDN such as Cloudflare: a
  /// V2Ray-style protocol over an HTTP-based transport, addressed by name.
  bool get isCdnCandidate {
    if (outbound.isXray) {
      return const {
            'xhttp',
            'ws',
            'grpc',
            'httpupgrade',
          }.contains(outbound.xrayNetwork) &&
          !_isIpLiteral(server);
    }
    final transport = outbound['transport'];
    return const {
          ProxyProtocol.vmess,
          ProxyProtocol.vless,
          ProxyProtocol.trojan,
        }.contains(protocol) &&
        transport is Map &&
        const {
          'ws',
          'grpc',
          'httpupgrade',
          'http',
        }.contains(transport['type']) &&
        !_isIpLiteral(server);
  }

  /// A copy that connects to [address] (a "clean" CDN IP) while still
  /// presenting the original host name in TLS (SNI) and in the HTTP Host
  /// header, so the CDN routes it to the same server.
  ProxyConfig withAddress(String address) {
    final copy = (jsonDecode(jsonEncode(outbound)) as Map)
        .cast<String, Object?>();
    if (copy.isXray) {
      copy.xrayServer?['address'] = address;
      final stream = copy.xrayStream;
      final tls = stream['tlsSettings'] as Map?;
      if (tls != null) {
        final sni = tls['serverName'];
        if (sni is! String || sni.isEmpty) tls['serverName'] = server;
      }
      for (final key in const [
        'xhttpSettings',
        'wsSettings',
        'httpupgradeSettings',
      ]) {
        final settings = stream[key] as Map?;
        if (settings != null) settings['host'] ??= server;
      }
      return ProxyConfig(
        protocol: protocol,
        name: '$name · $address',
        server: address,
        port: port,
        outbound: copy,
        via: via,
      );
    }
    copy['server'] = address;
    final tls = copy['tls'];
    if (tls is Map && tls['enabled'] == true) {
      final sni = tls['server_name'];
      if (sni is! String || sni.isEmpty) tls['server_name'] = server;
    }
    final transport = copy['transport'];
    if (transport is Map) {
      switch (transport['type']) {
        case 'ws':
          final headers = (transport['headers'] as Map?) ?? {};
          headers.putIfAbsent('Host', () => server);
          transport['headers'] = headers;
        case 'httpupgrade':
          transport['host'] ??= server;
        case 'http':
          transport['host'] ??= [server];
      }
    }
    return ProxyConfig(
      protocol: protocol,
      name: '$name · $address',
      server: address,
      port: port,
      outbound: copy,
      via: via,
    );
  }

  static bool _isIpLiteral(String host) =>
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) || host.contains(':');

  ProxyConfig copyWith({String? name}) => ProxyConfig(
    protocol: protocol,
    name: name ?? this.name,
    server: server,
    port: port,
    outbound: outbound,
    link: protocol == ProxyProtocol.openconnect && name != null
        ? openConnectLink(outbound, name)
        : link,
    via: via,
  );

  Map<String, Object?> toJson() => {
    'protocol': protocol.name,
    'name': name,
    'server': server,
    'port': port,
    'outbound': outbound,
    if (link != null) 'link': link,
    if (via != null) 'via': via!.toJson(),
  };

  factory ProxyConfig.fromJson(Map<String, Object?> json) => ProxyConfig(
    protocol: ProxyProtocol.values.byName(json['protocol']! as String),
    name: json['name']! as String,
    server: json['server']! as String,
    port: json['port']! as int,
    outbound: Map<String, Object?>.from(json['outbound']! as Map),
    link: json['link'] as String?,
    via: json['via'] is Map
        ? ProxyConfig.fromJson((json['via']! as Map).cast<String, Object?>())
        : null,
  );

  /// Pretty printed sing-box outbound, handy for "copy as JSON".
  String toPrettyJson({String tag = 'proxy'}) =>
      const JsonEncoder.withIndent('  ').convert({'tag': tag, ...outbound});

  @override
  String toString() => 'ProxyConfig(${protocol.name}, $name, $server:$port)';
}

/// Thrown when a share link is malformed.
class LinkParseException implements Exception {
  const LinkParseException(this.message);

  final String message;

  @override
  String toString() => 'LinkParseException: $message';
}

/// Thrown when a link is well formed but uses a feature sing-box does not
/// implement (for example the Xray-only `xhttp` transport or mKCP).
class UnsupportedLinkException extends LinkParseException {
  const UnsupportedLinkException(super.message);

  @override
  String toString() => 'UnsupportedLinkException: $message';
}
