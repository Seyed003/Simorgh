import 'dart:convert';

import '../encoding.dart';
import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

const _vmessSecurities = {
  'auto',
  'none',
  'zero',
  'aes-128-cfb',
  'aes-128-gcm',
  'chacha20-poly1305',
};

/// Parses `vmess://` links in both the v2rayN base64-JSON format and the
/// Xray URL format (`vmess://uuid@host:port?type=ws&security=tls#name`).
ProxyConfig parseVmess(String link) {
  final body = link.substring('vmess://'.length);
  final hash = body.indexOf('#');
  final payload = hash >= 0 ? body.substring(0, hash) : body;
  final decoded = tryDecodeBase64(payload);
  if (decoded != null && decoded.trimLeft().startsWith('{')) {
    return _parseV2rayNJson(link, decoded);
  }
  return _parseVmessUrl(link);
}

ProxyConfig _parseV2rayNJson(String link, String decoded) {
  final Object? raw;
  try {
    raw = jsonDecode(decoded);
  } on FormatException {
    throw const LinkParseException('vmess payload is not valid JSON');
  }
  if (raw is! Map) {
    throw const LinkParseException('vmess payload is not an object');
  }
  final json = raw.map((k, v) => MapEntry(k.toString(), v));

  String str(String key) => json[key]?.toString().trim() ?? '';

  final server = str('add');
  requireHost(server);
  final port = int.tryParse(str('port'));
  if (port == null || port <= 0 || port > 65535) {
    throw LinkParseException('invalid port "${str('port')}"');
  }
  final uuid = str('id');
  if (uuid.isEmpty) throw const LinkParseException('missing vmess id');

  final host = str('host');
  final sni = str('sni');
  final outbound = <String, Object?>{
    'type': 'vmess',
    'server': server,
    'server_port': port,
    'uuid': uuid,
    'security': _security(str('scy')),
    'alter_id': int.tryParse(str('aid')) ?? 0,
  };
  final tls = buildTls(
    security: str('tls'),
    serverName: sni.isNotEmpty
        ? sni
        : (host.isNotEmpty ? splitList(host).first : server),
    alpn: str('alpn'),
    fingerprint: str('fp'),
    insecure: _truthy(json['allowInsecure']) || _truthy(json['insecure']),
    realityPublicKey: str('pbk'),
    realityShortId: str('sid'),
  );
  if (tls != null) outbound['tls'] = tls;

  final network = str('net');
  final transport = buildTransport(
    network: network,
    host: host,
    path: str('path'),
    // v2rayN stores the gRPC service name in `path`.
    serviceName: network == 'grpc' ? str('path') : null,
    headerType: str('type'),
  );
  if (transport != null) outbound['transport'] = transport;

  final name = str('ps');
  return ProxyConfig(
    protocol: ProxyProtocol.vmess,
    name: name.isNotEmpty ? name : 'VMess $server:$port',
    server: server,
    port: port,
    outbound: outbound,
    link: link,
  );
}

ProxyConfig _parseVmessUrl(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final uuid = uri.decodedUserInfo ?? '';
  if (uuid.isEmpty) throw const LinkParseException('missing vmess id');
  final port = uri.port;
  final outbound = <String, Object?>{
    'type': 'vmess',
    'server': uri.host,
    'server_port': port,
    'uuid': uuid,
    'security': _security(uri.param(['encryption', 'scy'])),
    'alter_id': int.tryParse(uri.param(['aid', 'alterid']) ?? '') ?? 0,
  };
  final host = uri.param(['host']);
  final tls = buildTls(
    security: uri.param(['security']),
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
    protocol: ProxyProtocol.vmess,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'VMess ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}

String _security(String? value) {
  final v = (value ?? '').toLowerCase();
  return _vmessSecurities.contains(v) ? v : 'auto';
}

bool _truthy(Object? value) =>
    value == true || value == 1 || value == '1' || value == 'true';
