import 'dart:convert';

import '../proxy_config.dart';
import 'v2ray_common.dart';

/// Configs sing-box cannot run itself go to the Xray engine bundled in the
/// core as the `xray` outbound type (see core/xray): one Xray outbound object
/// that sing-box routes to like any other proxy.
const xrayOutboundType = 'xray';

/// Transports only Xray implements.
bool isXrayTransport(String? network) => const {
  'xhttp',
  'splithttp',
  'kcp',
  'mkcp',
}.contains(network?.toLowerCase());

/// Fingerprints Xray's uTLS accepts.
const _xrayFingerprints = {
  'chrome',
  'firefox',
  'safari',
  'ios',
  'android',
  'edge',
  '360',
  'qq',
  'random',
  'randomized',
  'randomizednoalpn',
};

/// XHTTP modes Xray accepts.
const _xhttpModes = {'auto', 'packet-up', 'stream-up', 'stream-one'};

String _xrayFingerprint(String? fp) {
  final value = (fp ?? '').toLowerCase();
  if (_xrayFingerprints.contains(value)) return value;
  if (value.startsWith('random')) return 'randomized';
  return 'chrome';
}

/// Old mKCP header types and their Xray 26 "finalmask" names.
const _kcpHeaders = {
  'srtp': 'header-srtp',
  'utp': 'header-utp',
  'wechat-video': 'header-wechat',
  'dtls': 'header-dtls',
  'wireguard': 'header-wireguard',
  'dns': 'header-dns',
};

/// Xray `streamSettings` from share-link fields.
///
/// `allowInsecure` is not carried over: Xray no longer accepts it, so such
/// configs verify the server certificate like any other (pin one with
/// [pinnedCertSha256], the links' `pcs`, to trust a self-signed server).
Map<String, Object?> xrayStreamSettings({
  required String? network,
  required String? security,
  String? serverName,
  String? alpn,
  String? fingerprint,
  String? pinnedCertSha256,
  String? verifyCertName,
  String? realityPublicKey,
  String? realityShortId,
  String? spiderX,
  String? host,
  String? path,
  String? serviceName,
  String? mode,
  String? extra,
  String? headerType,
  String? seed,
}) {
  final stream = <String, Object?>{};
  final hosts = splitList(host);
  switch ((network ?? 'tcp').toLowerCase()) {
    case '' || 'tcp' || 'raw':
      stream['network'] = 'raw';
    case 'ws' || 'websocket':
      stream['network'] = 'ws';
      stream['wsSettings'] = {
        if (path != null && path.isNotEmpty) 'path': path,
        if (hosts.isNotEmpty) 'host': hosts.first,
      };
    case 'grpc' || 'gun':
      stream['network'] = 'grpc';
      final name = serviceName ?? path ?? '';
      stream['grpcSettings'] = {
        if (name.isNotEmpty) 'serviceName': name,
        if (mode == 'multi') 'multiMode': true,
      };
    case 'httpupgrade':
      stream['network'] = 'httpupgrade';
      stream['httpupgradeSettings'] = {
        if (path != null && path.isNotEmpty) 'path': path,
        if (hosts.isNotEmpty) 'host': hosts.first,
      };
    case 'xhttp' || 'splithttp':
      stream['network'] = 'xhttp';
      Object? extraSettings;
      if (extra != null && extra.isNotEmpty) {
        try {
          extraSettings = jsonDecode(extra);
        } on FormatException {
          throw const LinkParseException('xhttp "extra" is not valid JSON');
        }
        if (extraSettings is! Map) {
          throw const LinkParseException('xhttp "extra" is not an object');
        }
      }
      // Panels often put the TCP header type ("none") where v2rayN keeps the
      // mode, and Xray refuses a mode it does not know.
      final xhttpMode = (mode ?? '').toLowerCase();
      stream['xhttpSettings'] = {
        'path': (path == null || path.isEmpty) ? '/' : path,
        if (hosts.isNotEmpty) 'host': hosts.first,
        'mode': _xhttpModes.contains(xhttpMode) ? xhttpMode : 'auto',
        'extra': ?extraSettings,
      };
    case 'kcp' || 'mkcp':
      stream['network'] = 'kcp';
      stream['kcpSettings'] = <String, Object?>{};
      final masks = <Map<String, Object?>>[];
      final header = (headerType ?? '').toLowerCase();
      if (header.isNotEmpty && header != 'none') {
        final type = _kcpHeaders[header];
        if (type == null) {
          throw UnsupportedLinkException('unknown mKCP header "$headerType"');
        }
        masks.add({
          'type': type,
          if (type == 'header-dns' && hosts.isNotEmpty)
            'settings': {'domain': hosts.first},
        });
      }
      masks.add(
        seed != null && seed.isNotEmpty
            ? {
                'type': 'mkcp-aes128gcm',
                'settings': {'password': seed},
              }
            : {'type': 'mkcp-original'},
      );
      stream['finalmask'] = {'udp': masks};
    default:
      throw UnsupportedLinkException('unknown transport "$network"');
  }

  switch ((security ?? '').toLowerCase()) {
    case '' || 'none' || 'false':
      break;
    case 'tls' || 'xtls':
      stream['security'] = 'tls';
      final alpnList = splitList(alpn);
      stream['tlsSettings'] = {
        if (serverName != null && serverName.isNotEmpty)
          'serverName': serverName,
        if (alpnList.isNotEmpty) 'alpn': alpnList,
        'fingerprint': _xrayFingerprint(fingerprint),
        if (pinnedCertSha256 != null && pinnedCertSha256.isNotEmpty)
          'pinnedPeerCertSha256': pinnedCertSha256,
        if (verifyCertName != null && verifyCertName.isNotEmpty)
          'verifyPeerCertByName': verifyCertName,
      };
    case 'reality':
      if (realityPublicKey == null || realityPublicKey.isEmpty) {
        throw const LinkParseException('reality requires a public key (pbk)');
      }
      stream['security'] = 'reality';
      stream['realitySettings'] = {
        if (serverName != null && serverName.isNotEmpty)
          'serverName': serverName,
        'fingerprint': _xrayFingerprint(fingerprint),
        'publicKey': realityPublicKey,
        if (realityShortId != null && realityShortId.isNotEmpty)
          'shortId': realityShortId,
        if (spiderX != null && spiderX.isNotEmpty) 'spiderX': spiderX,
      };
    default:
      throw UnsupportedLinkException('unsupported security "$security"');
  }
  return stream;
}

/// The sing-box outbound running [xray] (an Xray outbound object).
Map<String, Object?> xrayOutbound(Map<String, Object?> xray) => {
  'type': xrayOutboundType,
  'xray': xray,
};

Map<String, Object?> xrayVless({
  required String address,
  required int port,
  required String uuid,
  String? flow,
  String? encryption,
  required Map<String, Object?> stream,
}) => xrayOutbound({
  'protocol': 'vless',
  'settings': {
    'vnext': [
      {
        'address': address,
        'port': port,
        'users': [
          {
            'id': uuid,
            'encryption': (encryption == null || encryption.isEmpty)
                ? 'none'
                : encryption,
            if (flow != null && flow.isNotEmpty) 'flow': flow,
          },
        ],
      },
    ],
  },
  'streamSettings': stream,
});

Map<String, Object?> xrayVmess({
  required String address,
  required int port,
  required String uuid,
  required String security,
  required Map<String, Object?> stream,
}) => xrayOutbound({
  'protocol': 'vmess',
  'settings': {
    'vnext': [
      {
        'address': address,
        'port': port,
        'users': [
          {'id': uuid, 'security': security},
        ],
      },
    ],
  },
  'streamSettings': stream,
});

Map<String, Object?> xrayTrojan({
  required String address,
  required int port,
  required String password,
  required Map<String, Object?> stream,
}) => xrayOutbound({
  'protocol': 'trojan',
  'settings': {
    'servers': [
      {'address': address, 'port': port, 'password': password},
    ],
  },
  'streamSettings': stream,
});

/// Read access to the Xray parts of an `xray` outbound.
extension XrayOutboundView on Map<String, Object?> {
  bool get isXray => this['type'] == xrayOutboundType;

  Map<String, Object?>? get _xray => this['xray'] as Map<String, Object?>?;

  Map<String, Object?> get xrayStream =>
      (_xray?['streamSettings'] as Map<String, Object?>?) ?? const {};

  /// The server entry (`vnext[0]` or `servers[0]`).
  Map<String, Object?>? get xrayServer {
    final settings = _xray?['settings'] as Map<String, Object?>?;
    final list = (settings?['vnext'] ?? settings?['servers']) as List?;
    return list == null || list.isEmpty
        ? null
        : list.first as Map<String, Object?>;
  }

  String? get xrayNetwork => xrayStream['network'] as String?;

  String? get xraySecurity => xrayStream['security'] as String?;

  /// TLS or REALITY server name.
  String? get xrayServerName {
    final tls =
        (xrayStream['tlsSettings'] ?? xrayStream['realitySettings']) as Map?;
    return tls?['serverName'] as String?;
  }
}
