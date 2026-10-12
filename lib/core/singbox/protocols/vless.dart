import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

/// Parses `vless://uuid@host:port?security=reality&pbk=...#name`.
ProxyConfig parseVless(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final uuid = uri.decodedUserInfo ?? '';
  if (uuid.isEmpty) throw const LinkParseException('missing vless uuid');
  final port = uri.port;

  final encryption = uri.param(['encryption']);
  if (encryption != null && encryption != 'none') {
    throw UnsupportedLinkException(
      'vless encryption "$encryption" is not supported',
    );
  }

  final outbound = <String, Object?>{
    'type': 'vless',
    'server': uri.host,
    'server_port': port,
    'uuid': uuid,
  };

  final flow = uri.param(['flow']);
  if (flow != null) {
    if (!flow.startsWith('xtls-rprx-vision')) {
      throw UnsupportedLinkException('unsupported flow "$flow"');
    }
    // `xtls-rprx-vision-udp443` is an Xray client-side variant of vision.
    outbound['flow'] = 'xtls-rprx-vision';
  }

  final host = uri.param(['host']);
  final tls = buildTls(
    security: uri.param(['security']),
    serverName:
        uri.param(['sni', 'peer']) ??
        (host != null ? splitList(host).first : uri.host),
    alpn: uri.param(['alpn']),
    fingerprint: uri.param(['fp']),
    insecure: uri.flag(['allowinsecure', 'insecure']),
    realityPublicKey: uri.param(['pbk', 'publickey']),
    realityShortId: uri.param(['sid', 'shortid']),
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

  final packetEncoding = uri.param(['packetencoding']);
  if (packetEncoding == 'xudp' || packetEncoding == 'packetaddr') {
    outbound['packet_encoding'] = packetEncoding;
  }

  return ProxyConfig(
    protocol: ProxyProtocol.vless,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'VLESS ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}
