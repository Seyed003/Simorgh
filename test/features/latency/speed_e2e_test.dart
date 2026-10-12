@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/windows_vpn_platform.dart';
import 'package:aghelan_ghiamat/features/latency/data/speed_tester.dart';
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

/// Downloads from a local HTTP server through the real test core and a
/// local Shadowsocks server:
///
///     SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to a sing-box executable to run'
      : null;

  test('measures working, dead and invalid servers', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('speed-e2e');
    addTearDown(() => dir.delete(recursive: true));

    // Endless download: 64 KB chunks until the client hangs up.
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    final chunk = Uint8List(64 * 1024);
    http.listen((request) async {
      request.response.headers.contentType = ContentType.binary;
      try {
        for (var i = 0; i < 2000; i++) {
          request.response.add(chunk);
          await request.response.flush();
        }
        await request.response.close();
      } on Object {
        // Client stopped reading.
      }
    });

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
    final tester = SpeedTester(
      platform: platform,
      options: const CoreOptions(directDns: '1.1.1.1'),
      url: 'http://127.0.0.1:${http.port}/blob',
      duration: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 3),
    );
    final updates = await tester.run({
      'working': LinkParser.parse(_ss(serverPort)),
      'dead': LinkParser.parse(_ss(await _freePort())),
      'invalid': LinkParser.parse(
        _ss(serverPort, method: '2022-blake3-aes-128-gcm', password: 'short'),
      ),
    }).toList();

    final byId = {for (final u in updates) u.id: u.result};
    expect(byId.keys, unorderedEquals(['working', 'dead', 'invalid']));
    expect(
      byId['working']!.bytesPerSecond,
      greaterThan(SpeedTester.minBytes),
      reason: 'a local download should be fast',
    );
    expect(byId['dead']!.failure, LatencyFailure.unreachable);
    expect(byId['invalid']!.failure, LatencyFailure.invalidConfig);
    expect(await platform.isRunning(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('cancelling mid-download stops promptly', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('speed-cancel');
    addTearDown(() => dir.delete(recursive: true));

    // A slow, endless download.
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    http.listen((request) async {
      try {
        while (true) {
          request.response.add(Uint8List(1024));
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      } on Object {
        // Client went away.
      }
    });

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

    final platform = WindowsVpnPlatform(
      coreExecutable: binary,
      dataDirectory: () async => dir,
      elevationCheck: () async => true,
    );
    final tester = SpeedTester(
      platform: platform,
      options: const CoreOptions(directDns: '1.1.1.1'),
      url: 'http://127.0.0.1:${http.port}/slow',
      duration: const Duration(seconds: 30),
    );
    final subscription = tester
        .run({'slow': LinkParser.parse(_ss(serverPort))})
        .listen((_) {});
    // Give the core time to start and the download to begin.
    await Future<void>.delayed(const Duration(seconds: 2));

    final watch = Stopwatch()..start();
    await subscription.cancel().timeout(const Duration(seconds: 5));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    // The test core is down, so a new one can start right away.
    await platform.startTester(
      jsonEncode({
        'log': {'level': 'error'},
        'outbounds': [
          {'type': 'direct'},
        ],
      }),
    );
    await platform.stopTester();
  }, timeout: const Timeout(Duration(minutes: 1)));
}
