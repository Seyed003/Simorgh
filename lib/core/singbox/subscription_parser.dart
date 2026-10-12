import 'dart:convert';

import 'encoding.dart';
import 'link_parser.dart';
import 'protocols/xray_outbound.dart';
import 'proxy_config.dart';

/// A line that could not be imported, with the reason.
class SkippedEntry {
  const SkippedEntry(this.input, this.reason);

  final String input;
  final String reason;

  @override
  String toString() => 'SkippedEntry($reason: $input)';
}

class ParseResult {
  const ParseResult(this.proxies, this.skipped);

  final List<ProxyConfig> proxies;
  final List<SkippedEntry> skipped;

  bool get isEmpty => proxies.isEmpty;
}

const _proxyOutboundTypes = {
  'vmess',
  'vless',
  'trojan',
  'shadowsocks',
  'hysteria2',
  'hysteria',
  'tuic',
  'ssh',
  'anytls',
  'socks',
  'wireguard',
};

/// Parses any text a user can paste or a subscription server can return:
/// newline separated share links, base64 of the same, a sing-box JSON
/// config / outbound, or a mixture of links and arbitrary text.
final _linkStart = RegExp(
  '(?<=\\s)(?=(?:${LinkParser.supportedSchemes.join('|')})://)',
  caseSensitive: false,
);

abstract final class SubscriptionParser {
  static ParseResult parse(String content) {
    final text = content.replaceFirst('﻿', '').trim();
    if (text.isEmpty) return const ParseResult([], []);

    if (text.startsWith('{') || text.startsWith('[')) {
      final json = _tryJson(text);
      if (json != null) {
        return _isXrayJson(json)
            ? _parseXrayJson(json)
            : _parseSingBoxJson(json);
      }
    }

    if (!text.contains('://')) {
      final decoded = tryDecodeBase64(text);
      if (decoded != null && decoded.contains('://')) {
        return _parseLines(decoded);
      }
    }
    return _parseLines(text);
  }

  static ParseResult _parseLines(String text) {
    final proxies = <ProxyConfig>[];
    final skipped = <SkippedEntry>[];
    for (final token in _tokens(text)) {
      if (!token.contains('://')) {
        // A base64 blob inside a plain list (some panels nest them).
        final decoded = tryDecodeBase64(token);
        if (decoded != null && decoded.contains('://')) {
          final nested = _parseLines(decoded);
          proxies.addAll(nested.proxies);
          skipped.addAll(nested.skipped);
        }
        continue;
      }
      try {
        proxies.add(LinkParser.parse(token));
      } on LinkParseException catch (e) {
        skipped.add(SkippedEntry(token, e.message));
      }
    }
    return ParseResult(proxies, skipped);
  }

  /// Splits [text] into candidate links: one per line, plus extra splits
  /// before any known scheme so several links pasted on one line still
  /// work. Remarks may legitimately contain raw spaces, so plain whitespace
  /// is not a separator.
  static Iterable<String> _tokens(String text) sync* {
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith('//')) {
        continue;
      }
      for (final chunk in trimmed.split(_linkStart)) {
        final token = chunk.trim();
        if (token.isNotEmpty) yield token;
      }
    }
  }

  static Object? _tryJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static ParseResult _parseSingBoxJson(Object json) {
    final candidates = <Map<String, Object?>>[];
    void collect(Object? value) {
      if (value is List) {
        for (final item in value) {
          if (item is Map) candidates.add(item.cast<String, Object?>());
        }
      }
    }

    if (json is Map) {
      final map = json.cast<String, Object?>();
      if (map['type'] is String) {
        candidates.add(map);
      } else {
        collect(map['outbounds']);
        collect(map['endpoints']);
      }
    } else {
      collect(json);
    }

    final proxies = <ProxyConfig>[];
    final skipped = <SkippedEntry>[];
    for (final item in candidates) {
      final type = item['type'];
      if (type is! String || !_proxyOutboundTypes.contains(type)) continue;
      final protocol = ProxyProtocol.fromSingBoxType(type)!;
      final server = _serverOf(item);
      final port = _portOf(item);
      if (server == null || port == null) {
        skipped.add(
          SkippedEntry(item['tag']?.toString() ?? type, 'missing server'),
        );
        continue;
      }
      final outbound = Map<String, Object?>.from(item)
        // Tags, detours and resolvers reference objects of the source config
        // that do not exist in ours.
        ..remove('tag')
        ..remove('detour')
        ..remove('domain_resolver')
        ..remove('domain_strategy');
      final tag = item['tag'];
      proxies.add(
        ProxyConfig(
          protocol: protocol,
          name: tag is String && tag.isNotEmpty
              ? tag
              : '${protocol.displayName} $server:$port',
          server: server,
          port: port,
          outbound: outbound,
        ),
      );
    }
    return ParseResult(proxies, skipped);
  }

  /// Xray/v2ray JSON (outbounds with `protocol`, not sing-box's `type`):
  /// one config, or a list of them as some subscriptions serve.
  static bool _isXrayJson(Object json) {
    bool isXrayOutbound(Object? o) => o is Map && o['protocol'] is String;
    bool isXrayConfig(Object? c) =>
        c is Map &&
        c['outbounds'] is List &&
        (c['outbounds'] as List).any(isXrayOutbound);
    if (json is List) {
      return json.any((c) => isXrayConfig(c) || isXrayOutbound(c));
    }
    return isXrayConfig(json) || isXrayOutbound(json);
  }

  static const _xrayProtocols = {
    'vless': ProxyProtocol.vless,
    'vmess': ProxyProtocol.vmess,
    'trojan': ProxyProtocol.trojan,
    'shadowsocks': ProxyProtocol.shadowsocks,
  };

  static ParseResult _parseXrayJson(Object json) {
    final configs = <Map<String, Object?>>[];
    for (final item in json is List ? json : [json]) {
      if (item is! Map) continue;
      final map = item.cast<String, Object?>();
      configs.add(
        map['outbounds'] is List
            ? map
            : {
                'outbounds': [map],
              },
      );
    }
    final proxies = <ProxyConfig>[];
    final skipped = <SkippedEntry>[];
    for (final config in configs) {
      final outbounds = [
        for (final o in config['outbounds']! as List)
          if (o is Map) o.cast<String, Object?>(),
      ];
      final remarks = config['remarks'];
      final proxyOutbounds = outbounds
          .where((o) => _xrayProtocols.containsKey(o['protocol']))
          .toList();
      for (final (i, item) in proxyOutbounds.indexed) {
        final protocol = _xrayProtocols[item['protocol']]!;
        final xray =
            (jsonDecode(jsonEncode(item)) as Map).cast<String, Object?>()
              ..remove('tag');
        final outbound = xrayOutbound(xray);
        final server = outbound.xrayServer ?? (xray['settings'] as Map?);
        final address = server?['address'];
        final port = server?['port'];
        final label = remarks is String && remarks.isNotEmpty
            ? (proxyOutbounds.length > 1 ? '$remarks #${i + 1}' : remarks)
            : null;
        if (address is! String || address.isEmpty || port is! int) {
          skipped.add(
            SkippedEntry(label ?? protocol.displayName, 'missing server'),
          );
          continue;
        }
        final stream = xray['streamSettings'];
        if (stream is Map) {
          // Fragmentation lives in another outbound of the source config.
          final sockopt = stream['sockopt'];
          if (sockopt is Map && sockopt['dialerProxy'] is String) {
            final helper = outbounds
                .where((o) => o['tag'] == sockopt['dialerProxy'])
                .firstOrNull;
            final fragment = (helper?['settings'] as Map?)?['fragment'];
            if (fragment != null) outbound['fragment'] = fragment;
            sockopt.remove('dialerProxy');
          }
          // Xray no longer skips certificate checks; neither do we.
          (stream['tlsSettings'] as Map?)?.remove('allowInsecure');
        }
        proxies.add(
          ProxyConfig(
            protocol: protocol,
            name: label ?? '${protocol.displayName} $address:$port',
            server: address,
            port: port,
            outbound: outbound,
          ),
        );
      }
    }
    return ParseResult(proxies, skipped);
  }

  static String? _serverOf(Map<String, Object?> item) {
    final server = item['server'];
    if (server is String && server.isNotEmpty) return server;
    final peers = item['peers'];
    if (peers is List && peers.isNotEmpty && peers.first is Map) {
      final address = (peers.first as Map)['address'];
      if (address is String) return address;
    }
    return null;
  }

  static int? _portOf(Map<String, Object?> item) {
    final port = item['server_port'];
    if (port is int) return port;
    final peers = item['peers'];
    if (peers is List && peers.isNotEmpty && peers.first is Map) {
      final p = (peers.first as Map)['port'];
      if (p is int) return p;
    }
    if (item['type'] == 'hysteria2' && item['server_ports'] is List) return 443;
    return null;
  }
}
