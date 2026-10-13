import 'dart:convert';

import '../proxy_config.dart';
import 'config_builder.dart';
import 'core_options.dart';

/// A config for the latency-test core: every server to test as its own
/// outbound (tag `t0`, `t1`, ...), no inbounds, and the Clash API to drive
/// `GET /proxies/{tag}/delay`.
class TestConfig {
  TestConfig._(this.json, this.tagToId, this._outboundTags, this._endpointTags);

  final Map<String, Object?> json;

  /// Outbound tag -> caller supplied id (e.g. profile id).
  final Map<String, String> tagToId;
  final List<String> _outboundTags;
  final List<String> _endpointTags;

  String encode() => jsonEncode(json);

  /// Maps a sing-box error such as `initialize outbound[3]: ...`,
  /// `initialize endpoint[0]: ...` or `outbounds[2].server_port: ...` to the
  /// id of the server it blames, or `null` when the error names none.
  String? idBlamedBy(String error) {
    final match = _blame.firstMatch(error);
    if (match == null) return null;
    final index = int.parse(match.group(2)!);
    final tags = match.group(1) == 'endpoint' ? _endpointTags : _outboundTags;
    if (index < 0 || index >= tags.length) return null;
    return tagToId[tags[index]];
  }

  static final _blame = RegExp(r'(outbound|endpoint)s?\[(\d+)\]');
}

class TestConfigBuilder {
  const TestConfigBuilder({required this.options, required this.clashApi});

  final CoreOptions options;
  final ClashApiOptions clashApi;

  /// [proxies] maps caller ids to the configs to test, in order.
  ///
  /// [localPorts] (by caller id) additionally exposes a server as an
  /// HTTP/SOCKS proxy on 127.0.0.1, e.g. for download speed tests. Other
  /// apps on the device can reach 127.0.0.1 too, so those proxies require
  /// [localAuth] when given.
  TestConfig build(
    Map<String, ProxyConfig> proxies, {
    Map<String, int> localPorts = const {},
    ({String username, String password})? localAuth,
  }) {
    final outbounds = <Map<String, Object?>>[];
    final endpoints = <Map<String, Object?>>[];
    final tagToId = <String, String>{};
    final outboundTags = <String>[];
    final endpointTags = <String>[];

    final inbounds = <Map<String, Object?>>[];
    final rules = <Map<String, Object?>>[];

    var i = 0;
    for (final MapEntry(key: id, value: proxy) in proxies.entries) {
      final tag = 't${i++}';
      tagToId[tag] = id;
      final port = localPorts[id];
      if (port != null) {
        inbounds.add({
          'type': 'mixed',
          'tag': 'in-$tag',
          'listen': '127.0.0.1',
          'listen_port': port,
          if (localAuth != null)
            'users': [
              {'username': localAuth.username, 'password': localAuth.password},
            ],
        });
        rules.add({
          'inbound': ['in-$tag'],
          'outbound': tag,
        });
      }
      final outbound = prepareOutbound(proxy, tag: tag, options: options);
      if (proxy.protocol.isEndpoint) {
        endpoints.add(outbound);
        endpointTags.add(tag);
      } else {
        outbounds.add(outbound);
        outboundTags.add(tag);
      }
    }
    // The direct outbound goes last so indexes of tested servers match
    // sing-box's outbound[N] numbering.
    outbounds.add({'type': 'direct', 'tag': ConfigTags.direct});
    outboundTags.add(ConfigTags.direct);

    final json = <String, Object?>{
      'log': {'level': 'error'},
      'dns': {
        'servers': directDnsServers(options),
        'strategy': options.enableIpv6 ? 'prefer_ipv4' : 'ipv4_only',
      },
      if (inbounds.isNotEmpty) 'inbounds': inbounds,
      if (endpoints.isNotEmpty) 'endpoints': endpoints,
      'outbounds': outbounds,
      'route': {
        if (rules.isNotEmpty) 'rules': rules,
        'final': ConfigTags.direct,
        // Bind test sockets to the physical interface so a running VPN
        // tunnel does not wrap the measurement.
        'auto_detect_interface': true,
        'default_domain_resolver': defaultDomainResolver(options),
      },
      'experimental': {
        'clash_api': {
          'external_controller': clashApi.controller,
          'secret': clashApi.secret,
        },
      },
    };
    return TestConfig._(json, tagToId, outboundTags, endpointTags);
  }
}
