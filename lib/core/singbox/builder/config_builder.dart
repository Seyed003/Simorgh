import 'dart:convert';

import '../protocols/xray_outbound.dart';
import '../proxy_config.dart';
import '../rules/iran_rules.dart';
import 'core_options.dart';
import 'dns_server.dart';

/// Tags used inside generated configs.
abstract final class ConfigTags {
  static const proxy = 'proxy';
  static const direct = 'direct';
  static const tunIn = 'tun-in';
  static const mixedIn = 'mixed-in';
  static const dnsRemote = 'dns-remote';
  static const dnsDirect = 'dns-direct';
  static const dnsLocal = 'dns-local';
}

const _tcpTlsTypes = {'vmess', 'vless', 'trojan', 'anytls'};
const _muxTypes = {'vmess', 'vless', 'trojan', 'shadowsocks'};

/// Wraps a [ProxyConfig] into a complete sing-box 1.14 configuration:
/// TUN inbound (VpnService on Android, wintun on Windows), DNS hijacking,
/// split DNS, private-network bypass and the Clash API for live stats.
class SingBoxConfigBuilder {
  const SingBoxConfigBuilder({
    required this.options,
    required this.platform,
    this.clashApi,
    this.cacheFilePath,
  });

  final CoreOptions options;
  final CorePlatform platform;
  final ClashApiOptions? clashApi;
  final String? cacheFilePath;

  Map<String, Object?> build(ProxyConfig proxy) {
    final outbound = _prepareOutbound(proxy);
    final isEndpoint = proxy.protocol.isEndpoint;
    return _assemble(
      outbounds: [if (!isEndpoint) outbound],
      endpoints: [if (isEndpoint) outbound],
    );
  }

  String buildJson(ProxyConfig proxy) =>
      const JsonEncoder.withIndent('  ').convert(build(proxy));

  /// Auto mode: every candidate as its own outbound ([autoTag]) behind a
  /// `urltest` group tagged `proxy`. The core keeps using the fastest
  /// candidate and moves to another one when it stops answering.
  ///
  /// The group re-tests every [interval], so that bounds how long a dead
  /// server stays in use. A switch also drops open connections, so
  /// [toleranceMs] is generous: a working server is only replaced for one
  /// that is clearly faster, not for jitter.
  Map<String, Object?> buildAuto(
    List<ProxyConfig> candidates, {
    String testUrl = defaultTestUrl,
    Duration interval = const Duration(minutes: 1),
    int toleranceMs = 150,
  }) {
    if (candidates.isEmpty) {
      throw ArgumentError.value(candidates, 'candidates', 'must not be empty');
    }
    final outbounds = <Map<String, Object?>>[];
    final endpoints = <Map<String, Object?>>[];
    final tags = <String>[];
    for (final (i, proxy) in candidates.indexed) {
      final tag = autoTag(i);
      tags.add(tag);
      final outbound = prepareOutbound(proxy, tag: tag, options: options);
      (proxy.protocol.isEndpoint ? endpoints : outbounds).add(outbound);
    }
    return _assemble(
      outbounds: [
        {
          'type': 'urltest',
          'tag': ConfigTags.proxy,
          'outbounds': tags,
          'url': testUrl,
          'interval': '${interval.inSeconds}s',
          'tolerance': toleranceMs,
          // Drop connections on a dead server right away instead of
          // letting apps hang until their own timeouts.
          'interrupt_exist_connections': true,
        },
        ...outbounds,
      ],
      endpoints: endpoints,
    );
  }

  String buildAutoJson(List<ProxyConfig> candidates) =>
      const JsonEncoder.withIndent('  ').convert(buildAuto(candidates));

  static String autoTag(int index) => 'auto-$index';

  /// Inverse of [autoTag]; `null` for any other tag.
  static int? autoIndexOf(String tag) =>
      tag.startsWith('auto-') ? int.tryParse(tag.substring(5)) : null;

  static const defaultTestUrl = 'https://www.gstatic.com/generate_204';

  Map<String, Object?> _assemble({
    required List<Map<String, Object?>> outbounds,
    required List<Map<String, Object?>> endpoints,
  }) {
    return {
      'log': {'level': options.logLevel, 'timestamp': true},
      'dns': _dns(),
      'inbounds': _inbounds(),
      if (endpoints.isNotEmpty) 'endpoints': endpoints,
      'outbounds': [
        ...outbounds,
        {'type': 'direct', 'tag': ConfigTags.direct},
      ],
      'route': _route(),
      'experimental': _experimental(),
    };
  }

  Map<String, Object?> _prepareOutbound(ProxyConfig proxy) =>
      prepareOutbound(proxy, tag: ConfigTags.proxy, options: options);

  Map<String, Object?> _dns() {
    final servers = <Map<String, Object?>>[];

    final remote = parseDnsServer(options.remoteDns, tag: ConfigTags.dnsRemote);
    if (remote['type'] != 'local') {
      remote['detour'] = ConfigTags.proxy;
      if (!isIpAddress(remote['server']! as String)) {
        remote['domain_resolver'] = ConfigTags.dnsDirect;
      }
    }
    servers
      ..add(remote)
      ..addAll(directDnsServers(options));

    return {
      'servers': servers,
      if (options.bypassIran)
        'rules': [
          // Iranian sites get their domestic answers, without a round trip
          // through the tunnel.
          {
            'rule_set': [IranRuleSets.domains],
            'server': ConfigTags.dnsDirect,
          },
        ],
      'final': ConfigTags.dnsRemote,
      'strategy': options.enableIpv6 ? 'prefer_ipv4' : 'ipv4_only',
    };
  }

  List<Map<String, Object?>> _inbounds() {
    final inbounds = <Map<String, Object?>>[];
    if (platform != CorePlatform.other) {
      inbounds.add({
        'type': 'tun',
        'tag': ConfigTags.tunIn,
        if (platform == CorePlatform.windows)
          'interface_name': 'AghelanGhiamat',
        'address': [
          '172.19.0.1/30',
          if (options.enableIpv6) 'fdfe:dcba:9876::1/126',
        ],
        'mtu': options.mtu,
        'auto_route': true,
        'strict_route': options.strictRoute,
        'stack': options.tunStack,
        ...?_perAppRules(),
      });
    }
    final port = options.mixedPort;
    if (port != null) {
      inbounds.add({
        'type': 'mixed',
        'tag': ConfigTags.mixedIn,
        'listen': '127.0.0.1',
        'listen_port': port,
      });
    }
    return inbounds;
  }

  /// Android's VpnService applies these as allowed/disallowed apps.
  Map<String, Object?>? _perAppRules() {
    final packages = options.perAppPackages;
    if (platform != CorePlatform.android || packages.isEmpty) return null;
    return switch (options.perAppMode) {
      PerAppMode.off => null,
      PerAppMode.include => {'include_package': packages},
      PerAppMode.exclude => {'exclude_package': packages},
    };
  }

  Map<String, Object?> _route() {
    return {
      'rules': [
        if (options.sniff) {'action': 'sniff'},
        {'protocol': 'dns', 'action': 'hijack-dns'},
        {'ip_is_private': true, 'outbound': ConfigTags.direct},
        if (options.bypassIran)
          {
            'rule_set': [IranRuleSets.domains, IranRuleSets.ips],
            'outbound': ConfigTags.direct,
          },
        // QUIC (HTTP/3) tunnelled through a TCP-based proxy is slow and
        // fragile; rejecting it makes browsers and apps fall back to TCP at
        // once, as Xray does with Vision. Domestic QUIC went direct above.
        if (options.blockQuic)
          {'network': 'udp', 'port': 443, 'action': 'reject'},
      ],
      if (options.bypassIran)
        'rule_set': iranRuleSets(ipv6: options.enableIpv6),
      'final': ConfigTags.proxy,
      'auto_detect_interface': true,
      'default_domain_resolver': defaultDomainResolver(options),
    };
  }

  Map<String, Object?> _experimental() {
    final api = clashApi;
    return {
      if (api != null)
        'clash_api': {
          'external_controller': api.controller,
          'secret': api.secret,
        },
      'cache_file': {
        'enabled': true,
        if (cacheFilePath != null) 'path': cacheFilePath,
      },
    };
  }
}

/// Copies [proxy]'s outbound with [tag] and applies the global options the
/// link itself does not set: uTLS fingerprint and TLS fragment on TCP TLS
/// protocols, multiplex on protocols that support it. The stored profile is
/// never mutated.
Map<String, Object?> prepareOutbound(
  ProxyConfig proxy, {
  required String tag,
  required CoreOptions options,
}) {
  final outbound = (jsonDecode(jsonEncode(proxy.outbound)) as Map)
      .cast<String, Object?>();
  outbound['tag'] = tag;
  final type = outbound['type'];
  final tls = outbound['tls'];
  if (_tcpTlsTypes.contains(type) && tls is Map && tls['enabled'] == true) {
    final fingerprint = options.defaultFingerprint;
    if (fingerprint != null && tls['utls'] == null) {
      tls['utls'] = {'enabled': true, 'fingerprint': fingerprint};
    }
    final hasFragment =
        tls['fragment'] != null || tls['record_fragment'] != null;
    switch (options.tlsFragment) {
      case TlsFragmentMode.off:
        break;
      case TlsFragmentMode.record when !hasFragment:
        tls['record_fragment'] = true;
      case TlsFragmentMode.tcp when !hasFragment:
        tls['fragment'] = true;
      case TlsFragmentMode.record || TlsFragmentMode.tcp:
        break;
    }
  }
  if (outbound.isXray) _prepareXray(outbound, options);
  // UDP the way Xray-based clients send it (one connection, many
  // destinations); Xray servers expect it.
  if (const {'vless', 'vmess'}.contains(type) &&
      outbound['packet_encoding'] == null) {
    outbound['packet_encoding'] = 'xudp';
  }
  // XTLS Vision (any `flow`) cannot be multiplexed.
  final flow = outbound['flow'];
  if (options.mux &&
      _muxTypes.contains(type) &&
      outbound['multiplex'] == null &&
      (flow == null || flow == '')) {
    outbound['multiplex'] = {'enabled': true, 'protocol': options.muxProtocol};
  }
  return outbound;
}

/// TLS fragmentation for configs on the Xray engine is Xray's own: the
/// ClientHello split into TLS records sent at once (light), or into small
/// TCP segments sent apart (strong).
void _prepareXray(Map<String, Object?> outbound, CoreOptions options) {
  if (outbound['fragment'] != null ||
      outbound.xrayNetwork == 'kcp' ||
      outbound.xraySecurity != 'tls') {
    return;
  }
  switch (options.tlsFragment) {
    case TlsFragmentMode.off:
      break;
    case TlsFragmentMode.record:
      outbound['fragment'] = {
        'packets': 'tlshello',
        'length': '100-200',
        'interval': '0',
      };
    case TlsFragmentMode.tcp:
      outbound['fragment'] = {
        'packets': 'tlshello',
        'length': '10-20',
        'interval': '10-20',
      };
  }
}

/// The direct DNS server (plus a `local` resolver when it is a hostname).
List<Map<String, Object?>> directDnsServers(CoreOptions options) {
  final direct = parseDnsServer(options.directDns, tag: ConfigTags.dnsDirect);
  if (direct['type'] == 'local' || isIpAddress(direct['server']! as String)) {
    return [direct];
  }
  direct['domain_resolver'] = ConfigTags.dnsLocal;
  return [
    direct,
    {'type': 'local', 'tag': ConfigTags.dnsLocal},
  ];
}

Map<String, Object?> defaultDomainResolver(CoreOptions options) => {
  'server': ConfigTags.dnsDirect,
  'strategy': options.enableIpv6 ? 'prefer_ipv4' : 'ipv4_only',
};
