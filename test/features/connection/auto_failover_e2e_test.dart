@Tags(['singbox'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/features/connection/data/clash_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

Future<void> _waitForPort(int port) async {
  for (var i = 0; i < 50; i++) {
    try {
      await (await Socket.connect('127.0.0.1', port)).close();
      return;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  fail('port $port never opened');
}

/// Runs the auto-mode config (without TUN) on the real core with two local
/// Shadowsocks servers, kills the one in use and expects the core to move
/// to the other:
///
///     SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to a sing-box executable to run'
      : null;

  test('auto mode fails over to a working server', skip: skip, () async {
    final dir = await Directory.systemTemp.createTemp('auto-e2e');
    addTearDown(() => dir.delete(recursive: true));

    Future<(Process, String)> shadowsocks(String name) async {
      final port = await _freePort();
      final file = File('${dir.path}/$name.json')
        ..writeAsStringSync(
          jsonEncode({
            'log': {'level': 'error'},
            'inbounds': [
              {
                'type': 'shadowsocks',
                'listen': '127.0.0.1',
                'listen_port': port,
                'method': 'aes-128-gcm',
                'password': 'test-pass',
              },
            ],
            'outbounds': [
              {'type': 'direct'},
            ],
          }),
        );
      final process = await Process.start(binary!, ['run', '-c', file.path]);
      addTearDown(process.kill);
      await _waitForPort(port);
      final userInfo = base64Url
          .encode(utf8.encode('aes-128-gcm:test-pass'))
          .replaceAll('=', '');
      return (process, 'ss://$userInfo@127.0.0.1:$port#$name');
    }

    final servers = [await shadowsocks('a'), await shadowsocks('b')];
    final mixedPort = await _freePort();
    final api = ClashApiOptions(port: await _freePort(), secret: 'secret');
    final config =
        SingBoxConfigBuilder(
          options: CoreOptions(mixedPort: mixedPort, directDns: '1.1.1.1'),
          platform: CorePlatform.other,
          clashApi: api,
        ).buildAuto([
          for (final (_, link) in servers) LinkParser.parse(link),
        ], interval: const Duration(seconds: 2));
    final file = File('${dir.path}/client.json')
      ..writeAsStringSync(jsonEncode(config));
    final client = await Process.start(binary!, [
      'run',
      '-c',
      file.path,
      '-D',
      dir.path,
    ]);
    addTearDown(client.kill);
    await _waitForPort(mixedPort);

    // The group only measures while traffic flows through it.
    final http = HttpClient()
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$mixedPort')
      ..connectionTimeout = const Duration(seconds: 3);
    addTearDown(() => http.close(force: true));
    Future<void> browse() async {
      try {
        final request = await http.getUrl(
          Uri.parse(SingBoxConfigBuilder.defaultTestUrl),
        );
        await (await request.close().timeout(const Duration(seconds: 3)))
            .drain<void>();
      } on Object {
        // Failures are expected while the core switches servers.
      }
    }

    final clash = ClashApiClient(api);
    Future<String> waitForNow(bool Function(String tag) accept) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        await browse();
        final now = await clash.proxyNow(ConfigTags.proxy);
        if (now != null && accept(now)) return now;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      fail('the urltest group never settled');
    }

    final first = await waitForNow((_) => true);
    final index = SingBoxConfigBuilder.autoIndexOf(first)!;
    servers[index].$1.kill();
    final second = await waitForNow((tag) => tag != first);
    expect(second, SingBoxConfigBuilder.autoTag(1 - index));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
