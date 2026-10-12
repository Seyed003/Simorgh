@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/test_config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/clash_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// A real request through a local Trojan+TLS server with multiplex enabled,
/// once per TLS fragment mode, to prove the generated client options work
/// with the real core:
///
///     SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to a sing-box executable to run'
      : null;

  late Directory dir;
  late int serverPort;

  setUpAll(() async {
    if (skip != null) return;
    dir = await Directory.systemTemp.createTemp('fragment-mux');
    final pair = await Process.run(binary!, [
      'generate',
      'tls-keypair',
      'example.local',
    ]);
    final pem = pair.stdout as String;
    final certStart = pem.indexOf('-----BEGIN CERTIFICATE-----');
    File('${dir.path}/key.pem').writeAsStringSync(pem.substring(0, certStart));
    File('${dir.path}/cert.pem').writeAsStringSync(pem.substring(certStart));

    serverPort = await _freePort();
    final config = File('${dir.path}/server.json')
      ..writeAsStringSync(
        jsonEncode({
          'log': {'level': 'error'},
          'inbounds': [
            {
              'type': 'trojan',
              'listen': '127.0.0.1',
              'listen_port': serverPort,
              'users': [
                {'password': 'test-pass'},
              ],
              'tls': {
                'enabled': true,
                'server_name': 'example.local',
                'certificate_path': '${dir.path}/cert.pem',
                'key_path': '${dir.path}/key.pem',
              },
              'multiplex': {'enabled': true},
            },
          ],
          'outbounds': [
            {'type': 'direct'},
          ],
        }),
      );
    final server = await Process.start(binary, ['run', '-c', config.path]);
    addTearDown(server.kill);
    for (var i = 0; i < 50; i++) {
      try {
        await (await Socket.connect('127.0.0.1', serverPort)).close();
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });
  tearDownAll(() async {
    if (skip == null && dir.existsSync()) await dir.delete(recursive: true);
  });

  for (final (mode, protocol) in [
    (TlsFragmentMode.record, 'h2mux'),
    (TlsFragmentMode.tcp, 'smux'),
  ]) {
    test(
      'fragment ${mode.name} + $protocol through a real server',
      skip: skip,
      () async {
        final api = ClashApiOptions(port: await _freePort(), secret: 's');
        final proxy = LinkParser.parse(
          'trojan://test-pass@127.0.0.1:$serverPort'
          '?security=tls&sni=example.local&allowInsecure=1#local',
        );
        final config = TestConfigBuilder(
          options: CoreOptions(
            tlsFragment: mode,
            mux: true,
            muxProtocol: protocol,
          ),
          clashApi: api,
        ).build({'local': proxy});
        final outbound = (config.json['outbounds']! as List).first as Map;
        expect(outbound['multiplex'], {'enabled': true, 'protocol': protocol});
        expect(
          (outbound['tls']! as Map)[mode == TlsFragmentMode.tcp
              ? 'fragment'
              : 'record_fragment'],
          isTrue,
        );

        // The test core normally only logs errors.
        final json = {
          ...config.json,
          'log': {'level': 'info'},
        };
        final file = File('${dir.path}/client-${mode.name}.json')
          ..writeAsStringSync(jsonEncode(json));
        final client = await Process.start(binary!, [
          'run',
          '-c',
          file.path,
          '-D',
          dir.path,
          '--disable-color',
        ]);
        addTearDown(client.kill);
        final log = StringBuffer();
        for (final stream in [client.stdout, client.stderr]) {
          stream.transform(utf8.decoder).listen(log.write);
        }

        final clash = ClashApiClient(api);
        for (var i = 0; i < 50 && !await clash.ping(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        final delay = await clash.delay(
          't0',
          url: SingBoxConfigBuilder.defaultTestUrl,
          timeout: const Duration(seconds: 8),
        );
        expect(delay, isNotNull, reason: log.toString());
        expect(log.toString(), contains('outbound multiplex connection'));
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  }
}
