import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What a server presented in its TLS handshake.
class ServerCertificate {
  const ServerCertificate({
    required this.trusted,
    required this.pin,
    required this.subject,
    required this.validUntil,
  });

  /// The device trusts it (a public CA, matching name): nothing to pin.
  final bool trusted;

  /// `pin-sha256:` fingerprint of its public key, as OpenConnect prints it.
  final String pin;
  final String subject;
  final DateTime validUntil;
}

/// Connects to [host]:[port] only to look at its certificate, so a server
/// with a self-signed one can be trusted by fingerprint, the way the Cisco
/// app asks "connect anyway?". Returns `null` when the server cannot be
/// reached.
Future<ServerCertificate?> probeCertificate(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  X509Certificate? untrusted;
  SecureSocket? socket;
  try {
    socket = await SecureSocket.connect(
      host,
      port,
      timeout: timeout,
      onBadCertificate: (certificate) {
        untrusted = certificate;
        return true;
      },
    );
    final certificate = untrusted ?? socket.peerCertificate;
    if (certificate == null) return null;
    return ServerCertificate(
      trusted: untrusted == null,
      pin: spkiPin(certificate.der),
      subject: certificate.subject,
      validUntil: certificate.endValidity,
    );
  } on Object {
    return null;
  } finally {
    socket?.destroy();
  }
}

/// `pin-sha256:<base64>`: SHA-256 of the certificate's SubjectPublicKeyInfo.
String spkiPin(Uint8List der) {
  final certificate = _Der.read(der, 0).children();
  final tbs = certificate.first.children();
  // An explicit version ([0]) comes first in v3 certificates; then serial,
  // signature algorithm, issuer, validity, subject, public key.
  final start = tbs.first.tag == 0xA0 ? 1 : 0;
  final spki = tbs[start + 5];
  return 'pin-sha256:${base64.encode(sha256.convert(spki.encoded).bytes)}';
}

/// One DER element: just enough ASN.1 to find the public key.
class _Der {
  _Der(this._data, this.tag, this._start, this._contentStart, this._end);

  factory _Der.read(Uint8List data, int offset) {
    final tag = data[offset];
    var length = data[offset + 1];
    var content = offset + 2;
    if (length & 0x80 != 0) {
      final bytes = length & 0x7F;
      length = 0;
      for (var i = 0; i < bytes; i++) {
        length = (length << 8) | data[content + i];
      }
      content += bytes;
    }
    if (content + length > data.length) {
      throw const FormatException('truncated certificate');
    }
    return _Der(data, tag, offset, content, content + length);
  }

  final Uint8List _data;
  final int tag;
  final int _start;
  final int _contentStart;
  final int _end;

  Uint8List get encoded => Uint8List.sublistView(_data, _start, _end);

  List<_Der> children() {
    final result = <_Der>[];
    var offset = _contentStart;
    while (offset < _end) {
      final child = _Der.read(_data, offset);
      result.add(child);
      offset = child._end;
    }
    return result;
  }
}
