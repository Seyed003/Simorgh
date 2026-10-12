import '../proxy_config.dart';

/// Converts a user facing DNS address into a sing-box (1.12+) DNS server.
///
/// Supported forms: `local`, `1.1.1.1`, `udp://1.1.1.1:53`, `tcp://..`,
/// `tls://..`, `quic://..`, `https://host/path`, `h3://host/path`.
Map<String, Object?> parseDnsServer(String address, {required String tag}) {
  final value = address.trim();
  if (value.isEmpty) throw const LinkParseException('empty DNS address');
  if (value == 'local' || value == 'system') {
    return {'type': 'local', 'tag': tag};
  }

  final hasScheme = value.contains('://');
  final scheme = hasScheme
      ? value.substring(0, value.indexOf('://')).toLowerCase()
      : 'udp';
  final type = switch (scheme) {
    'udp' => 'udp',
    'tcp' => 'tcp',
    'tls' || 'dot' => 'tls',
    'quic' || 'doq' => 'quic',
    'https' || 'doh' => 'https',
    'h3' || 'http3' => 'h3',
    _ => throw LinkParseException('unsupported DNS scheme "$scheme"'),
  };

  final uri = Uri.parse(
    hasScheme
        ? '$scheme://${value.substring(value.indexOf('://') + 3)}'
        : 'udp://$value',
  );
  if (uri.host.isEmpty) {
    throw LinkParseException('invalid DNS address "$address"');
  }
  final server = <String, Object?>{
    'type': type,
    'tag': tag,
    'server': uri.host,
  };
  if (uri.hasPort) server['server_port'] = uri.port;
  if ((type == 'https' || type == 'h3') &&
      uri.path.isNotEmpty &&
      uri.path != '/dns-query') {
    server['path'] = uri.path;
  }
  return server;
}

final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

/// Whether [host] is an IP literal (and thus needs no resolver).
bool isIpAddress(String host) => _ipv4.hasMatch(host) || host.contains(':');
