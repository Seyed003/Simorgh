import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';
import 'xray_outbound.dart';

/// Parses `vless://uuid@host:port?security=reality&pbk=...#name`.
ProxyConfig parseVless(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final uuid = uri.decodedUserInfo ?? '';
  if (uuid.isEmpty) throw const LinkParseException('missing vless uuid');
  final port = uri.port;

  final encryption = uri.param(['encryption']);
  final network = uri.param(['type', 'net']);
  final host = uri.param(['host']);
  final serverName =
      uri.param(['sni', 'peer']) ??
      (host != null ? splitList(host).first : uri.host);
  final name = uri.fragment.isNotEmpty
      ? uri.fragment
      : 'VLESS ${uri.host}:$port';

  // XHTTP, mKCP and VLESS Encryption run on the bundled Xray engine.
  if (isXrayTransport(network) ||
      (encryption != null && encryption != 'none')) {
    return ProxyConfig(
      protocol: ProxyProtocol.vless,
      name: name,
      server: uri.host,
      port: port,
      outbound: xrayVless(
        address: uri.host,
        port: port,
        uuid: uuid,
        flow: uri.param(['flow']),
        encryption: encryption,
        stream: xrayStreamSettings(
          network: network,
          security: uri.param(['security']),
          serverName: serverName,
          alpn: uri.param(['alpn']),
          fingerprint: uri.param(['fp']),
          pinnedCertSha256: uri.param(['pcs']),
          verifyCertName: uri.param(['vcn']),
          realityPublicKey: uri.param(['pbk', 'publickey']),
          realityShortId: uri.param(['sid', 'shortid']),
          spiderX: uri.param(['spx', 'spiderx']),
          host: host,
          path: uri.param(['path']),
          serviceName: uri.param(['servicename']),
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

  final tls = buildTls(
    security: uri.param(['security']),
    serverName: serverName,
    alpn: uri.param(['alpn']),
    fingerprint: uri.param(['fp']),
    insecure: uri.flag(['allowinsecure', 'insecure']),
    realityPublicKey: uri.param(['pbk', 'publickey']),
    realityShortId: uri.param(['sid', 'shortid']),
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

  final packetEncoding = uri.param(['packetencoding']);
  if (packetEncoding == 'xudp' || packetEncoding == 'packetaddr') {
    outbound['packet_encoding'] = packetEncoding;
  }

  return ProxyConfig(
    protocol: ProxyProtocol.vless,
    name: name,
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}
