import '../encoding.dart';
import '../proxy_config.dart';
import '../share_uri.dart';

/// Parses `socks://base64(user:pass)@host:port` (v2rayN) and
/// `socks5://user:pass@host:port` / `socks4://` / `socks4a://`.
ProxyConfig parseSocks(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final port = uri.port;
  final version = switch (uri.scheme) {
    'socks4' => '4',
    'socks4a' => '4a',
    _ => '5',
  };

  String? username;
  String? password;
  final raw = uri.decodedUserInfo;
  if (raw != null && raw.isNotEmpty) {
    final credentials = raw.contains(':') ? raw : (tryDecodeBase64(raw) ?? raw);
    final colon = credentials.indexOf(':');
    username = colon >= 0 ? credentials.substring(0, colon) : credentials;
    password = colon >= 0 ? credentials.substring(colon + 1) : null;
  }

  return ProxyConfig(
    protocol: ProxyProtocol.socks,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'SOCKS ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: {
      'type': 'socks',
      'server': uri.host,
      'server_port': port,
      'version': version,
      if (username != null && username.isNotEmpty) 'username': username,
      if (password != null && password.isNotEmpty) 'password': password,
    },
    link: link,
  );
}
