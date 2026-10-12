import 'dart:convert';

import '../proxy_config.dart';
import '../share_uri.dart';
import 'v2ray_common.dart';

/// Parses `wireguard://privateKey@host:port?publickey=..&address=..#name`
/// (also `wg://`) into a sing-box WireGuard *endpoint*.
ProxyConfig parseWireGuard(String link) {
  final uri = ShareUri.parse(link);
  requireHost(uri.host);
  final port = uri.portSpec.isEmpty ? 51820 : uri.port;

  final privateKey =
      uri.decodedUserInfo ?? uri.param(['privatekey', 'private_key']);
  if (privateKey == null || privateKey.isEmpty) {
    throw const LinkParseException('missing wireguard private key');
  }
  final publicKey = uri.param([
    'publickey',
    'public_key',
    'peer_public_key',
    'peerpublickey',
  ]);
  if (publicKey == null) {
    throw const LinkParseException('missing wireguard public key');
  }

  final addresses = splitList(uri.param(['address', 'ip', 'local_address']))
      .map((a) => a.contains('/') ? a : (a.contains(':') ? '$a/128' : '$a/32'))
      .toList();
  if (addresses.isEmpty) {
    throw const LinkParseException('missing wireguard interface address');
  }

  final peer = <String, Object?>{
    'address': uri.host,
    'port': port,
    'public_key': publicKey,
    'allowed_ips': ['0.0.0.0/0', '::/0'],
  };
  final psk = uri.param(['presharedkey', 'pre_shared_key', 'psk']);
  if (psk != null) peer['pre_shared_key'] = psk;
  final reserved = _parseReserved(uri.param(['reserved']));
  if (reserved != null) peer['reserved'] = reserved;
  final keepalive = int.tryParse(
    uri.param([
          'keepalive',
          'persistentkeepalive',
          'persistent_keepalive_interval',
        ]) ??
        '',
  );
  if (keepalive != null && keepalive > 0) {
    peer['persistent_keepalive_interval'] = keepalive;
  }

  final endpoint = <String, Object?>{
    'type': 'wireguard',
    'address': addresses,
    'private_key': privateKey,
    'peers': [peer],
  };
  final mtu = int.tryParse(uri.param(['mtu']) ?? '');
  if (mtu != null && mtu > 0) endpoint['mtu'] = mtu;

  return ProxyConfig(
    protocol: ProxyProtocol.wireguard,
    name: uri.fragment.isNotEmpty
        ? uri.fragment
        : 'WireGuard ${uri.host}:$port',
    server: uri.host,
    port: port,
    outbound: endpoint,
    link: link,
  );
}

/// `reserved` is either `1,2,3` or the base64 encoding of three bytes.
List<int>? _parseReserved(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.contains(',')) {
    final bytes = value.split(',').map((e) => int.tryParse(e.trim())).toList();
    if (bytes.length == 3 &&
        bytes.every((b) => b != null && b >= 0 && b < 256)) {
      return bytes.cast<int>();
    }
    throw LinkParseException('invalid wireguard reserved "$value"');
  }
  try {
    final bytes = base64.decode(base64.normalize(value));
    if (bytes.length == 3) return bytes;
  } on FormatException {
    // fall through
  }
  throw LinkParseException('invalid wireguard reserved "$value"');
}
