import '../proxy_config.dart';

/// uTLS fingerprints sing-box accepts.
const _fingerprints = {
  'chrome',
  'chrome_psk',
  'chrome_psk_shuffle',
  'chrome_padding_psk_shuffle',
  'chrome_pq',
  'chrome_pq_psk',
  'firefox',
  'edge',
  'safari',
  '360',
  'qq',
  'ios',
  'android',
  'random',
  'randomized',
};

/// Maps an Xray/v2rayN fingerprint name to the sing-box equivalent.
String? normalizeFingerprint(String? fp) {
  if (fp == null || fp.isEmpty || fp == 'none') return null;
  final value = fp.toLowerCase();
  if (_fingerprints.contains(value)) return value;
  if (value.startsWith('random')) return 'randomized';
  if (value.startsWith('chrome')) return 'chrome';
  if (value.startsWith('firefox')) return 'firefox';
  if (value.startsWith('safari')) return 'safari';
  if (value.startsWith('edge')) return 'edge';
  return 'chrome';
}

List<String> splitList(String? value) => value == null
    ? const []
    : value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// Builds the sing-box `tls` object for V2Ray-family links.
///
/// [security] is the link's `security`/`tls` value: `tls`, `xtls`, `reality`
/// or empty/`none` for plaintext.
Map<String, Object?>? buildTls({
  required String? security,
  required String? serverName,
  String? alpn,
  String? fingerprint,
  bool insecure = false,
  String? realityPublicKey,
  String? realityShortId,
}) {
  final mode = (security ?? '').toLowerCase();
  if (mode.isEmpty || mode == 'none' || mode == 'false') return null;
  if (mode != 'tls' && mode != 'xtls' && mode != 'reality') {
    throw UnsupportedLinkException('unsupported security "$security"');
  }

  final tls = <String, Object?>{'enabled': true};
  if (serverName != null && serverName.isNotEmpty) {
    tls['server_name'] = serverName;
  }
  if (insecure) tls['insecure'] = true;
  final alpnList = splitList(alpn);
  if (alpnList.isNotEmpty) tls['alpn'] = alpnList;

  var fp = normalizeFingerprint(fingerprint);
  if (mode == 'reality') {
    if (realityPublicKey == null || realityPublicKey.isEmpty) {
      throw const LinkParseException('reality requires a public key (pbk)');
    }
    // sing-box only implements REALITY on top of uTLS.
    fp ??= 'chrome';
    tls['reality'] = {
      'enabled': true,
      'public_key': realityPublicKey,
      if (realityShortId != null && realityShortId.isNotEmpty)
        'short_id': realityShortId,
    };
  }
  if (fp != null) tls['utls'] = {'enabled': true, 'fingerprint': fp};
  return tls;
}

final _earlyDataPattern = RegExp(r'[?&]ed=(\d+)');

/// Builds the sing-box V2Ray `transport` object.
///
/// Returns `null` for raw TCP. Throws [UnsupportedLinkException] for
/// transports that only exist in Xray (xhttp/splithttp, mKCP).
Map<String, Object?>? buildTransport({
  required String? network,
  String? host,
  String? path,
  String? serviceName,
  String? headerType,
}) {
  final type = (network ?? 'tcp').toLowerCase();
  final hosts = splitList(host);

  switch (type) {
    case '':
    case 'tcp':
    case 'raw':
      if ((headerType ?? '').toLowerCase() != 'http') return null;
      // TCP with HTTP header obfuscation maps to plain HTTP/1.1 transport.
      return {
        'type': 'http',
        if (hosts.isNotEmpty) 'host': hosts,
        'path': (path == null || path.isEmpty) ? '/' : path,
        'method': 'GET',
      };
    case 'ws':
    case 'websocket':
      final ws = <String, Object?>{'type': 'ws'};
      var wsPath = path ?? '';
      final earlyData = _earlyDataPattern.firstMatch(wsPath);
      if (earlyData != null) {
        ws['max_early_data'] = int.parse(earlyData.group(1)!);
        ws['early_data_header_name'] = 'Sec-WebSocket-Protocol';
        wsPath = wsPath.replaceFirst(_earlyDataPattern, '');
        if (wsPath.contains('&') && !wsPath.contains('?')) {
          wsPath = wsPath.replaceFirst('&', '?');
        }
      }
      if (wsPath.isNotEmpty) ws['path'] = wsPath;
      if (hosts.isNotEmpty) {
        ws['headers'] = {'Host': hosts.first};
      }
      return ws;
    case 'grpc':
    case 'gun':
      final name = (serviceName != null && serviceName.isNotEmpty)
          ? serviceName
          : (path ?? '');
      return {'type': 'grpc', if (name.isNotEmpty) 'service_name': name};
    case 'http':
    case 'h2':
      return {
        'type': 'http',
        if (hosts.isNotEmpty) 'host': hosts,
        if (path != null && path.isNotEmpty) 'path': path,
      };
    case 'httpupgrade':
      return {
        'type': 'httpupgrade',
        if (hosts.isNotEmpty) 'host': hosts.first,
        if (path != null && path.isNotEmpty) 'path': path,
      };
    case 'quic':
      return {'type': 'quic'};
    case 'xhttp':
    case 'splithttp':
      throw const UnsupportedLinkException(
        'xhttp transport is Xray-only and not supported by sing-box',
      );
    case 'kcp':
    case 'mkcp':
      throw const UnsupportedLinkException(
        'mKCP transport is not supported by sing-box',
      );
    default:
      throw UnsupportedLinkException('unknown transport "$network"');
  }
}
