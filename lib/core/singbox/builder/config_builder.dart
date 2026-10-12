import 'dart:convert';

import '../proxy_config.dart';
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
    final proxyOutbound = _prepareOutbound(proxy);
    final isEndpoint = proxy.protocol.isEndpoint;

    return {
      'log': {'level': options.logLevel, 'timestamp': true},
      'dns': _dns(),
      'inbounds': _inbounds(),
      if (isEndpoint) 'endpoints': [proxyOutbound],
      'outbounds': [
        if (!isEndpoint) proxyOutbound,
        {'type': 'direct', 'tag': ConfigTags.direct},
      ],
      'route': _route(),
      'experimental': _experimental(),
    };
  }

  String buildJson(ProxyConfig proxy) =>
      const JsonEncoder.withIndent('  ').convert(build(proxy));

  Map<String, Object?> _prepareOutbound(ProxyConfig proxy) {
    // Deep copy so the stored profile is never mutated.
    final outbound = (jsonDecode(jsonEncode(proxy.outbound)) as Map)
        .cast<String, Object?>();
    outbound['tag'] = ConfigTags.proxy;
    final fingerprint = options.defaultFingerprint;
    final tls = outbound['tls'];
    if (fingerprint != null &&
        _tcpTlsTypes.contains(outbound['type']) &&
        tls is Map &&
        tls['enabled'] == true &&
        tls['utls'] == null) {
      tls['utls'] = {'enabled': true, 'fingerprint': fingerprint};
    }
    return outbound;
  }

  Map<String, Object?> _dns() {
    final servers = <Map<String, Object?>>[];
    var needsLocal = false;

    final remote = parseDnsServer(options.remoteDns, tag: ConfigTags.dnsRemote);
    if (remote['type'] != 'local') {
      remote['detour'] = ConfigTags.proxy;
      if (!isIpAddress(remote['server']! as String)) {
        remote['domain_resolver'] = ConfigTags.dnsDirect;
      }
    }
    final direct = parseDnsServer(options.directDns, tag: ConfigTags.dnsDirect);
    if (direct['type'] != 'local' &&
        !isIpAddress(direct['server']! as String)) {
      direct['domain_resolver'] = ConfigTags.dnsLocal;
      needsLocal = true;
    }
    servers
      ..add(remote)
      ..add(direct);
    if (needsLocal) servers.add({'type': 'local', 'tag': ConfigTags.dnsLocal});

    return {
      'servers': servers,
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

  Map<String, Object?> _route() {
    return {
      'rules': [
        if (options.sniff) {'action': 'sniff'},
        {'protocol': 'dns', 'action': 'hijack-dns'},
        {'ip_is_private': true, 'outbound': ConfigTags.direct},
      ],
      'final': ConfigTags.proxy,
      'auto_detect_interface': true,
      'default_domain_resolver': {
        'server': ConfigTags.dnsDirect,
        'strategy': options.enableIpv6 ? 'prefer_ipv4' : 'ipv4_only',
      },
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
