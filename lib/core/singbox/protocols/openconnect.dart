import '../proxy_config.dart';
import '../share_uri.dart';

/// A Cisco AnyConnect / ocserv server as a sing-box `openconnect` endpoint.
///
/// [address] is `host`, `host:port` or an `https://` URL (a path selects a
/// group on some servers). [pin] trusts a self-signed certificate by its
/// `pin-sha256:` fingerprint.
ProxyConfig openConnectConfig({
  required String address,
  required String username,
  required String password,
  String? group,
  String? pin,
  String? name,
}) {
  final (host, port, path) = _splitAddress(address);
  final outbound = <String, Object?>{
    'type': 'openconnect',
    'server': 'https://${_hostPort(host, port)}$path',
    'username': username,
    'password': password,
    if (group != null && group.isNotEmpty) 'auth_group': group,
    if (pin != null && pin.isNotEmpty)
      'tls': {
        'peer_fingerprint': [pin],
      },
  };
  final label = name != null && name.trim().isNotEmpty
      ? name.trim()
      : 'Cisco $host';
  return ProxyConfig(
    protocol: ProxyProtocol.openconnect,
    name: label,
    server: host,
    port: port,
    outbound: outbound,
    link: openConnectLink(outbound, label),
  );
}

/// Parses `openconnect://user:pass@host:port/path?group=…&pin=…#name`
/// (also `anyconnect://` and `cisco://`), the link this app shares.
ProxyConfig parseOpenConnect(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final user = uri.decodedUserInfo ?? '';
  final colon = user.indexOf(':');
  return openConnectConfig(
    address:
        '${_hostPort(uri.host, uri.portSpec.isEmpty ? 443 : uri.port)}'
        '${uri.path}',
    username: colon < 0 ? user : user.substring(0, colon),
    password: colon < 0 ? '' : user.substring(colon + 1),
    group: uri.param(['group', 'authgroup', 'auth_group']),
    pin: uri.param(['pin', 'servercert', 'fingerprint']),
    name: uri.fragment,
  );
}

/// The share link of an `openconnect` endpoint, credentials included.
String openConnectLink(Map<String, Object?> outbound, String name) {
  final server = Uri.parse(outbound['server']! as String);
  final user = Uri.encodeComponent((outbound['username'] as String?) ?? '');
  final password = Uri.encodeComponent((outbound['password'] as String?) ?? '');
  final pins = ((outbound['tls'] as Map?)?['peer_fingerprint'] as List?)
      ?.cast<String>();
  final query = {
    if (outbound['auth_group'] case final String group) 'group': group,
    if (pins != null && pins.isNotEmpty) 'pin': pins.first,
  };
  final host = server.host.contains(':') ? '[${server.host}]' : server.host;
  return 'openconnect://$user:$password@$host:${server.port}'
      '${server.path}'
      '${query.isEmpty ? '' : '?${Uri(queryParameters: query).query}'}'
      '#${Uri.encodeComponent(name)}';
}

(String, int, String) _splitAddress(String address) {
  var text = address.trim();
  if (text.isEmpty) {
    throw const LinkParseException('missing server address');
  }
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    throw LinkParseException('invalid server "$address"');
  }
  final path = uri.path == '/' ? '' : uri.path;
  return (uri.host, uri.hasPort ? uri.port : 443, path);
}

String _hostPort(String host, int port) =>
    host.contains(':') ? '[$host]:$port' : '$host:$port';
