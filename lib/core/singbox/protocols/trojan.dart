import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';
import 'xray_outbound.dart';

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

  final host = uri.param(['host']);
  final network = uri.param(['type', 'net']);
  final serverName =
      uri.param(['sni', 'peer']) ??
      (host != null ? splitList(host).first : uri.host);
  final name = uri.fragment.isNotEmpty
      ? uri.fragment
      : 'Trojan ${uri.host}:$port';
  if (isXrayTransport(network) ||
      needsXrayCertCheck(
        security: uri.param(['security']) ?? 'tls',
        pinnedCertSha256: uri.param(['pcs']),
        verifyCertName: uri.param(['vcn']),
      )) {
    return ProxyConfig(
      protocol: ProxyProtocol.trojan,
      name: name,
      server: uri.host,
      port: port,
      outbound: xrayTrojan(
        address: uri.host,
        port: port,
        password: password,
        stream: xrayStreamSettings(
          network: network,
          security: uri.param(['security']) ?? 'tls',
          serverName: serverName,
          alpn: uri.param(['alpn']),
          fingerprint: uri.param(['fp']),
          pinnedCertSha256: uri.param(['pcs']),
          verifyCertName: uri.param(['vcn']),
          realityPublicKey: uri.param(['pbk']),
          realityShortId: uri.param(['sid']),
          spiderX: uri.param(['spx']),
          host: host,
          path: uri.param(['path']),
          mode: uri.param(['mode']),
          extra: uri.param(['extra']),
          headerType: uri.param(['headertype']),
          seed: uri.param(['seed']),
        ),
      ),
      link: link,
    );
  }

  final outbound = <String, Object?>{
    'type': 'trojan',
    'server': uri.host,
    'server_port': port,
    'password': password,
  };
  final tls = buildTls(
    security: uri.param(['security']) ?? 'tls',
    serverName: serverName,
    alpn: uri.param(['alpn']),
    fingerprint: uri.param(['fp']),
    insecure: uri.flag(['allowinsecure', 'insecure']),
    realityPublicKey: uri.param(['pbk']),
    realityShortId: uri.param(['sid']),
  );
  if (tls != null) outbound['tls'] = tls;

  final transport = buildTransport(
    network: network,
    host: host,
    path: uri.param(['path']),
    serviceName: uri.param(['servicename']),
    headerType: uri.param(['headertype']),
  );
  if (transport != null) outbound['transport'] = transport;

  return ProxyConfig(
    protocol: ProxyProtocol.trojan,
    name: name,
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}
