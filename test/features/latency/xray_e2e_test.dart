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

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

/// Downloads through XHTTP and mKCP configs on the core's Xray engine, from
/// a local Xray server:
///
///     SING_BOX_BIN=build/core/sing-box XRAY_BIN=/path/to/xray \
///       flutter test --tags singbox
///
/// (build/core/sing-box comes from `scripts/build_core.sh linux amd64
/// build/core/sing-box`; the official sing-box release has no Xray engine.)
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final xray = Platform.environment['XRAY_BIN'];
  final skip =
      binary == null ||
          !File(binary).existsSync() ||
          xray == null ||
          !File(xray).existsSync()
      ? 'set SING_BOX_BIN (with Xray) and XRAY_BIN to run'
      : null;

  test('XHTTP and mKCP links carry traffic', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('xray-e2e');
    addTearDown(() => dir.delete(recursive: true));

    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    final chunk = Uint8List(64 * 1024);
    http.listen((request) async {
      try {
        for (var i = 0; i < 400; i++) {
          request.response.add(chunk);
          await request.response.flush();
        }
        await request.response.close();
      } on Object {
        // Client stopped reading.
      }
    });

    final xhttp = await _freePort();
    final vmessXhttp = await _freePort();
    final kcp = await _freePort();
    Map<String, Object?> inbound(
      int port,
      String protocol,
      Map<String, Object?> stream,
    ) => {
      'listen': '127.0.0.1',
      'port': port,
      'protocol': protocol,
      'settings': {
        'clients': [
          {'id': _uuid},
        ],
        if (protocol == 'vless') 'decryption': 'none',
      },
      'streamSettings': stream,
    };
    final serverConfig = File('${dir.path}/xray.json')
      ..writeAsStringSync(
        jsonEncode({
          'log': {'loglevel': 'error'},
          'inbounds': [
            inbound(xhttp, 'vless', {
              'network': 'xhttp',
              'xhttpSettings': {'path': '/xh'},
            }),
            inbound(vmessXhttp, 'vmess', {
              'network': 'xhttp',
              'xhttpSettings': {'path': '/vm', 'mode': 'packet-up'},
            }),
            inbound(kcp, 'vless', {
              'network': 'kcp',
              'finalmask': {
                'udp': [
                  {'type': 'header-wechat'},
                  {
                    'type': 'mkcp-aes128gcm',
                    'settings': {'password': 's33d'},
                  },
                ],
              },
            }),
          ],
          'outbounds': [
            {'protocol': 'freedom'},
          ],
        }),
      );
    final server = await Process.start(xray!, ['run', '-c', serverConfig.path]);
    addTearDown(server.kill);
    await Future<void>.delayed(const Duration(seconds: 1));

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
      connectTimeout: const Duration(seconds: 5),
    );
    final vmess = base64.encode(
      utf8.encode(
        jsonEncode({
          'v': '2',
          'add': '127.0.0.1',
          'port': '$vmessXhttp',
          'id': _uuid,
          'net': 'xhttp',
          'type': 'packet-up',
          'path': '/vm',
          'tls': '',
        }),
      ),
    );
    final updates = await tester.run({
      'xhttp': LinkParser.parse(
        'vless://$_uuid@127.0.0.1:$xhttp?type=xhttp&path=%2Fxh&security=none#x',
      ),
      'vmess': LinkParser.parse('vmess://$vmess'),
      'kcp': LinkParser.parse(
        'vless://$_uuid@127.0.0.1:$kcp?type=kcp&headerType=wechat-video&seed=s33d#k',
      ),
      'wrong-seed': LinkParser.parse(
        'vless://$_uuid@127.0.0.1:$kcp?type=kcp&headerType=wechat-video&seed=nope#w',
      ),
    }).toList();

    final byId = {for (final u in updates) u.id: u.result};
    for (final id in ['xhttp', 'vmess', 'kcp']) {
      expect(
        byId[id]!.bytesPerSecond,
        greaterThan(SpeedTester.minBytes),
        reason: '$id should download',
      );
    }
    expect(byId['wrong-seed']!.ok, isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
