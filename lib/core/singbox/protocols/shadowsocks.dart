import '../encoding.dart';
import '../proxy_config.dart';
import '../share_uri.dart';

const shadowsocksMethods = {
  'none',
  'aes-128-gcm',
  'aes-192-gcm',
  'aes-256-gcm',
  'chacha20-ietf-poly1305',
  'xchacha20-ietf-poly1305',
  '2022-blake3-aes-128-gcm',
  '2022-blake3-aes-256-gcm',
  '2022-blake3-chacha20-poly1305',
  'aes-128-ctr',
  'aes-192-ctr',
  'aes-256-ctr',
  'aes-128-cfb',
  'aes-192-cfb',
  'aes-256-cfb',
  'rc4-md5',
  'chacha20-ietf',
  'xchacha20',
};

const _methodAliases = {
  'chacha20-poly1305': 'chacha20-ietf-poly1305',
  'xchacha20-poly1305': 'xchacha20-ietf-poly1305',
  'plain': 'none',
};

/// Parses SIP002 (`ss://base64(method:pass)@host:port`), SIP002 with a plain
/// user info (common for 2022 ciphers) and the legacy fully base64 form.
ProxyConfig parseShadowsocks(String link) {
  var normalized = link;
  final body = link.substring('ss://'.length);
  final hash = body.indexOf('#');
  final main = hash >= 0 ? body.substring(0, hash) : body;
  final beforeQuery = main.split('?').first;
  if (!beforeQuery.contains('@')) {
    // Legacy: ss://base64(method:password@host:port)#tag
    final encoded = beforeQuery.endsWith('/')
        ? beforeQuery.substring(0, beforeQuery.length - 1)
        : beforeQuery;
    final decoded = tryDecodeBase64(percentDecode(encoded));
    if (decoded == null || !decoded.contains('@')) {
      throw const LinkParseException('invalid shadowsocks link');
    }
    final rest = main.substring(beforeQuery.length);
    normalized = 'ss://$decoded$rest${hash >= 0 ? body.substring(hash) : ''}';
  }

  final uri = ShareUri.parse(normalized);
  requireHost(uri.host);
  final port = uri.port;
  final rawUser = uri.userInfo ?? '';
  final userInfo = percentDecode(rawUser);
  String credentials;
  if (userInfo.contains(':')) {
    credentials = userInfo;
  } else {
    credentials = tryDecodeBase64(userInfo) ?? '';
  }
  final colon = credentials.indexOf(':');
  if (colon <= 0) throw const LinkParseException('missing shadowsocks method');
  var method = credentials.substring(0, colon).toLowerCase();
  method = _methodAliases[method] ?? method;
  final password = credentials.substring(colon + 1);
  if (!shadowsocksMethods.contains(method)) {
    throw UnsupportedLinkException('unsupported shadowsocks method "$method"');
  }

  final outbound = <String, Object?>{
    'type': 'shadowsocks',
    'server': uri.host,
    'server_port': port,
    'method': method,
    'password': password,
  };

  final plugin = uri.param(['plugin']);
  if (plugin != null) {
    final semicolon = plugin.indexOf(';');
    var name = semicolon >= 0 ? plugin.substring(0, semicolon) : plugin;
    final opts = semicolon >= 0 ? plugin.substring(semicolon + 1) : '';
    if (name == 'simple-obfs') name = 'obfs-local';
    if (name != 'obfs-local' && name != 'v2ray-plugin') {
      throw UnsupportedLinkException('unsupported shadowsocks plugin "$name"');
    }
    outbound['plugin'] = name;
    if (opts.isNotEmpty) outbound['plugin_opts'] = opts;
  }
  if (uri.flag(['uot', 'udp-over-tcp'])) {
    outbound['udp_over_tcp'] = {'enabled': true, 'version': 2};
  }

  return ProxyConfig(
    protocol: ProxyProtocol.shadowsocks,
    name: uri.fragment.isNotEmpty ? uri.fragment : 'SS ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: outbound,
    link: link,
  );
}
