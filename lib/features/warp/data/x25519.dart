import 'dart:math';
import 'dart:typed_data';

/// X25519 (RFC 7748) for WireGuard keys; only used once per WARP account,
/// so plain BigInt arithmetic is fast enough.
final _p = (BigInt.one << 255) - BigInt.from(19);
final _a24 = BigInt.from(121665);

BigInt _decode(List<int> bytes) {
  var value = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i--) {
    value = (value << 8) | BigInt.from(bytes[i]);
  }
  return value;
}

Uint8List _encode(BigInt value) {
  final out = Uint8List(32);
  var v = value;
  for (var i = 0; i < 32; i++) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  return out;
}

/// Clamps a 32-byte private key as X25519 requires.
Uint8List clampPrivateKey(List<int> key) {
  final k = Uint8List.fromList(key);
  k[0] &= 248;
  k[31] &= 127;
  k[31] |= 64;
  return k;
}

/// The X25519 function: [scalar] times the point with coordinate [u].
Uint8List x25519(List<int> scalar, List<int> u) {
  final k = _decode(clampPrivateKey(scalar));
  final x1 = _decode([...u.take(31), u[31] & 127]) % _p;
  var x2 = BigInt.one, z2 = BigInt.zero, x3 = x1, z3 = BigInt.one;
  var swap = 0;
  for (var t = 254; t >= 0; t--) {
    final bit = ((k >> t) & BigInt.one).toInt();
    swap ^= bit;
    if (swap == 1) {
      (x2, x3) = (x3, x2);
      (z2, z3) = (z3, z2);
    }
    swap = bit;
    final a = (x2 + z2) % _p;
    final aa = (a * a) % _p;
    final b = (x2 - z2) % _p;
    final bb = (b * b) % _p;
    final e = (aa - bb) % _p;
    final c = (x3 + z3) % _p;
    final d = (x3 - z3) % _p;
    final da = (d * a) % _p;
    final cb = (c * b) % _p;
    x3 = ((da + cb) * (da + cb)) % _p;
    z3 = (x1 * ((da - cb) * (da - cb) % _p)) % _p;
    x2 = (aa * bb) % _p;
    z2 = (e * (aa + _a24 * e)) % _p;
  }
  if (swap == 1) {
    (x2, x3) = (x3, x2);
    (z2, z3) = (z3, z2);
  }
  return _encode((x2 * z2.modPow(_p - BigInt.two, _p)) % _p);
}

/// A new WireGuard key pair: (private, public), 32 bytes each.
(Uint8List, Uint8List) generateKeyPair([Random? random]) {
  final rng = random ?? Random.secure();
  final private = clampPrivateKey([
    for (var i = 0; i < 32; i++) rng.nextInt(256),
  ]);
  final basePoint = Uint8List(32)..[0] = 9;
  return (private, x25519(private, basePoint));
}
