import 'dart:convert';

import 'encoding.dart';
import 'link_parser.dart';
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
      if (json != null) return _parseSingBoxJson(json);
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
