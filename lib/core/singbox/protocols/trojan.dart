import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

/// Parses `trojan://password@host:port?sni=...&type=ws#name`.
/// Trojan implies TLS unless `security=none` is given explicitly.
ProxyConfig parseTrojan(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final password = uri.decodedUserInfo ?? '';
  if (password.isEmpty) {
    throw const LinkParseException('missing trojan password');
  }
  final port = uri.port;

  final outbound = <String, Object?>{
    'type': 'trojan',
    'server': uri.host,
    'server_port': port,
    'password': password,
  };
  final host = uri.param(['host']);
  final tls = buildTls(
    security: uri.param(['security']) ?? 'tls',
    serverName:
        uri.param(['sni', 'peer']) ??
        (host != null ? splitList(host).first : uri.host),
    alpn: uri.param(['alpn']),
    fingerprint: uri.param(['fp']),
    insecure: uri.flag(['allowinsecure', 'insecure']),
    realityPublicKey: uri.param(['pbk']),
    realityShortId: uri.param(['sid']),
  );
  if (tls != null) outbound['tls'] = tls;

  final transport = buildTransport(
    network: uri.param(['type', 'net']),
    host: host,
    path: uri.param(['path']),
    serviceName: uri.param(['servicename']),
    headerType: uri.param(['headertype']),
  );
  if (transport != null) outbound['transport'] = transport;

  return ProxyConfig(
    protocol: ProxyProtocol.trojan,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'Trojan ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}
