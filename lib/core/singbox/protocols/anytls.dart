import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

/// Parses `anytls://password@host:port?sni=..&insecure=1#name`.
ProxyConfig parseAnyTls(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final port = uri.port;
  final password = uri.decodedUserInfo ?? '';
  if (password.isEmpty) {
    throw const LinkParseException('missing anytls password');
  }

  final tls = buildTls(
    security: 'tls',
    serverName: uri.param(['sni', 'peer']) ?? uri.host,
    alpn: uri.param(['alpn']),
    fingerprint: uri.param(['fp']),
    insecure: uri.flag(['insecure', 'allowinsecure']),
  );
  return ProxyConfig(
    protocol: ProxyProtocol.anytls,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'AnyTLS ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: {
      'type': 'anytls',
      'server': uri.host,
      'server_port': port,
      'password': password,
      'tls': tls,
    },
    link: link,
  );
}
