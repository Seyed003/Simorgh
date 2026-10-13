import 'dart:convert';
import 'dart:typed_data';

import 'package:aghelan_ghiamat/features/warp/data/x25519.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('RFC 7748 test vectors', () {
    expect(
      _toHex(
        x25519(
          _hex(
            'a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4',
          ),
          _hex(
            'e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c',
          ),
        ),
      ),
      'c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552',
    );
    final basePoint = Uint8List(32)..[0] = 9;
    final alicePrivate = _hex(
      '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
    );
    final bobPrivate = _hex(
      '5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb',
    );
    final alicePublic = x25519(alicePrivate, basePoint);
    final bobPublic = x25519(bobPrivate, basePoint);
    expect(
      _toHex(alicePublic),
      '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a',
    );
    expect(
      _toHex(bobPublic),
      'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f',
    );
    // Both sides agree on the shared secret.
    expect(
      _toHex(x25519(alicePrivate, bobPublic)),
      '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742',
    );
    expect(x25519(bobPrivate, alicePublic), x25519(alicePrivate, bobPublic));
  });

  test('generated key pairs are clamped and consistent', () {
    final (private, public) = generateKeyPair();
    expect(private[0] & 7, 0);
    expect(private[31] & 128, 0);
    expect(private[31] & 64, 64);
    expect(x25519(private, Uint8List(32)..[0] = 9), public);
    expect(base64.encode(public), hasLength(44));
  });
}
