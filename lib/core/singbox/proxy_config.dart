import 'dart:convert';

/// Protocols the parser understands. `wireguard` is emitted as a sing-box
/// endpoint, every other protocol as an outbound.
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
  socks('SOCKS', 'socks');

  const ProxyProtocol(this.displayName, this.singBoxType);

  final String displayName;

  /// The `type` value sing-box uses for this protocol.
  final String singBoxType;

  bool get isEndpoint => this == ProxyProtocol.wireguard;

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

  /// Short transport/security summary for list tiles, e.g. `ws · tls`.
  String get summary {
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

  /// Host name the server is reached by in TLS (SNI), else the address.
  String get tlsHost {
    final tls = outbound['tls'];
    final sni = tls is Map ? tls['server_name'] : null;
    return sni is String && sni.isNotEmpty ? sni : server;
  }

  /// Looks like a config served through a CDN such as Cloudflare: a
  /// V2Ray-style protocol over an HTTP-based transport, addressed by name.
  bool get isCdnCandidate {
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
    link: link,
  );

  Map<String, Object?> toJson() => {
    'protocol': protocol.name,
    'name': name,
    'server': server,
    'port': port,
    'outbound': outbound,
    if (link != null) 'link': link,
  };

  factory ProxyConfig.fromJson(Map<String, Object?> json) => ProxyConfig(
    protocol: ProxyProtocol.values.byName(json['protocol']! as String),
    name: json['name']! as String,
    server: json['server']! as String,
    port: json['port']! as int,
    outbound: Map<String, Object?>.from(json['outbound']! as Map),
    link: json['link'] as String?,
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
