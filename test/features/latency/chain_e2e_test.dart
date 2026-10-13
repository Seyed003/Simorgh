@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/windows_vpn_platform.dart';
import 'package:aghelan_ghiamat/features/latency/data/speed_tester.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// A config chained through another server really goes through it:
///
///     SING_BOX_BIN=/abs/path/to/sing-box flutter test --tags singbox
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to run'
      : null;

  test(
    'traffic reaches the target through the first server',
    skip: skip,
    () async {
      final dir = await Directory.systemTemp.createTemp('chain-e2e');
      addTearDown(() => dir.delete(recursive: true));

      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => http.close(force: true));
      final chunk = Uint8List(64 * 1024);
      http.listen((request) async {
        try {
          for (var i = 0; i < 100; i++) {
            request.response.add(chunk);
            await request.response.flush();
          }
          await request.response.close();
        } on Object {
          // Client stopped reading.
        }
      });

      // The "domestic relay" (SOCKS) and the "foreign server" (Shadowsocks).
      final relay = await _freePort();
      final target = await _freePort();
      final log = File('${dir.path}/server.log');
      final serverConfig = File('${dir.path}/server.json')
        ..writeAsStringSync(
          jsonEncode({
            'log': {'level': 'info', 'output': log.path},
            'inbounds': [
              {
                'type': 'socks',
                'tag': 'relay-in',
                'listen': '127.0.0.1',
                'listen_port': relay,
              },
              {
                'type': 'shadowsocks',
                'tag': 'target-in',
                'listen': '127.0.0.1',
                'listen_port': target,
                'method': 'aes-128-gcm',
                'password': 'chain-test',
              },
            ],
            'outbounds': [
              {'type': 'direct'},
            ],
          }),
        );
      final core = await Process.start(binary!, [
        'run',
        '-c',
        serverConfig.path,
      ]);
      addTearDown(core.kill);
      await Future<void>.delayed(const Duration(seconds: 1));

      final ss = base64Url.encode(utf8.encode('aes-128-gcm:chain-test'));
      final chained = LinkParser.parse('ss://$ss@127.0.0.1:$target#foreign')
          .chainedVia(LinkParser.parse('socks5://127.0.0.1:$relay#domestic'));

      final tester = SpeedTester(
        platform: WindowsVpnPlatform(
          coreExecutable: binary,
          dataDirectory: () async => dir,
          elevationCheck: () async => true,
        ),
        options: const CoreOptions(directDns: '1.1.1.1'),
        url: 'http://127.0.0.1:${http.port}/blob',
        duration: const Duration(seconds: 1),
        connectTimeout: const Duration(seconds: 5),
      );
      final result = (await tester.run({
        'chain': chained,
      }).toList()).single.result;
      expect(result.bytesPerSecond, greaterThan(SpeedTester.minBytes));

      // The relay carried a connection to the Shadowsocks server.
      final text = await log.readAsString();
      expect(text, contains('inbound/socks[relay-in]'));
      expect(text, contains('127.0.0.1:$target'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
