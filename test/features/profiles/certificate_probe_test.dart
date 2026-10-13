import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/features/profiles/data/certificate_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/openvpn_fixtures.dart';

List<int> _der(String pem) => base64.decode(
  pem.replaceAll(RegExp('-----[A-Z ]+-----'), '').replaceAll(RegExp(r'\s'), ''),
);

void main() {
  test('pins match openssl pkey | sha256 | base64', () {
    expect(
      spkiPin(.fromList(_der(ovpnServerCert))),
      'pin-sha256:/Nd23qOHvCHzaLvNFVNGvJQQJyd37GlMeAzpIKsokp4=',
    );
    expect(
      spkiPin(.fromList(_der(ovpnCa))),
      'pin-sha256:XN7hamaVs07Mw1UYfiz/e8it89XPc0/dofMzhD3+UZk=',
    );
  });

  test('a self-signed server is reported untrusted, with its pin', () async {
    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(ovpnServerCert))
      ..usePrivateKeyBytes(utf8.encode(ovpnServerKey));
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    addTearDown(server.close);
    server.listen((socket) => socket.destroy(), onError: (_) {});

    final probed = await probeCertificate('127.0.0.1', server.port);
    expect(probed, isNotNull);
    expect(probed!.trusted, isFalse);
    expect(probed.pin, spkiPin(.fromList(_der(ovpnServerCert))));
    expect(probed.subject, contains('server'));
  });

  test('unreachable servers give null', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    expect(await probeCertificate('127.0.0.1', port), isNull);
  });
}
