@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/windows_vpn_platform.dart';
import 'package:aghelan_ghiamat/features/latency/data/latency_tester.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

String _ss(
  int port, {
  String method = 'aes-128-gcm',
  String password = 'test-pass',
}) =>
    'ss://${base64Url.encode(utf8.encode('$method:$password')).replaceAll('=', '')}@127.0.0.1:$port#local';

/// Runs the real test core (the desktop process implementation) against a
/// local Shadowsocks server, end to end:
///
///     SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to a sing-box executable to run'
      : null;

  test('measures working, dead and invalid servers', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('latency-e2e');
    addTearDown(() => dir.delete(recursive: true));

    // A local Shadowsocks server that forwards to the internet directly.
    final serverPort = await _freePort();
    final serverConfig = File('${dir.path}/server.json')
      ..writeAsStringSync(
        jsonEncode({
          'log': {'level': 'error'},
          'inbounds': [
            {
              'type': 'shadowsocks',
              'listen': '127.0.0.1',
              'listen_port': serverPort,
              'method': 'aes-128-gcm',
              'password': 'test-pass',
            },
          ],
          'outbounds': [
            {'type': 'direct'},
          ],
        }),
      );
    final server = await Process.start(binary!, [
      'run',
      '-c',
      serverConfig.path,
    ]);
    addTearDown(server.kill);
    for (var i = 0; i < 50; i++) {
      try {
        await (await Socket.connect('127.0.0.1', serverPort)).close();
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    final platform = WindowsVpnPlatform(
      coreExecutable: binary,
      dataDirectory: () async => dir,
      elevationCheck: () async => true,
    );
    final tester = LatencyTester(
      platform: platform,
      options: const CoreOptions(directDns: '1.1.1.1'),
      timeout: const Duration(seconds: 4),
    );
    final updates = await tester.run({
      'working': LinkParser.parse(_ss(serverPort)),
      'dead': LinkParser.parse(_ss(await _freePort())),
      // 2022 ciphers need a base64 key of the right length.
      'invalid': LinkParser.parse(
        _ss(serverPort, method: '2022-blake3-aes-128-gcm', password: 'short'),
      ),
    }).toList();

    final byId = {for (final u in updates) u.id: u.result};
    expect(
      byId['working']!.delay,
      isNotNull,
      reason: 'working server should answer',
    );
    expect(byId['working']!.delay, greaterThan(0));
    expect(byId['dead']!.failure, LatencyFailure.unreachable);
    expect(byId['invalid']!.failure, LatencyFailure.invalidConfig);
    expect(await platform.isRunning(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
