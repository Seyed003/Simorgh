import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/features/connection/data/clash_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses traffic lines', () {
    expect(ClashApiClient.parseTrafficLine('{"up":12,"down":34}'), (
      up: 12,
      down: 34,
    ));
    expect(ClashApiClient.parseTrafficLine(''), isNull);
    expect(ClashApiClient.parseTrafficLine('nope'), isNull);
  });

  test('proxyNow reads the selected member of a group', () async {
    final requested = <Uri>[];
    ClashApiClient client(http.Response response) => ClashApiClient(
      const ClashApiOptions(port: 9090, secret: 's'),
      clientFactory: () => MockClient((request) async {
        requested.add(request.url);
        return response;
      }),
    );
    expect(
      await client(
        http.Response('{"type":"URLTest","now":"auto-3","all":[]}', 200),
      ).proxyNow('proxy'),
      'auto-3',
    );
    expect(requested.single.path, '/proxies/proxy');
    expect(
      await client(http.Response('{"now":""}', 200)).proxyNow('proxy'),
      isNull,
    );
    expect(
      await client(http.Response('not found', 404)).proxyNow('proxy'),
      isNull,
    );
  });

  group('against a real sing-box core', () {
    final binary = Platform.environment['SING_BOX_BIN'];
    final skip = binary == null || !File(binary).existsSync()
        ? 'set SING_BOX_BIN to a sing-box executable to run'
        : null;

    test('ping and /traffic stream', skip: skip, () async {
      final dir = await Directory.systemTemp.createTemp('clash-api');
      addTearDown(() => dir.delete(recursive: true));
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final api = ClashApiOptions(port: port, secret: 'test-secret');
      final config = File('${dir.path}/config.json')
        ..writeAsStringSync(
          jsonEncode({
            'log': {'level': 'error'},
            'outbounds': [
              {'type': 'direct', 'tag': 'direct'},
            ],
            'experimental': {
              'clash_api': {
                'external_controller': api.controller,
                'secret': api.secret,
              },
            },
          }),
        );
      final process = await Process.start(binary!, [
        'run',
        '-c',
        config.path,
        '-D',
        dir.path,
      ]);
      addTearDown(process.kill);

      final client = ClashApiClient(api);
      var up = false;
      for (var i = 0; i < 50 && !up; i++) {
        up = await client.ping();
        if (!up) await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(up, isTrue);
      expect(
        await ClashApiClient(ClashApiOptions(port: port, secret: 'wrong'))
            .ping(),
        isFalse,
      );

      final sample = await client.traffic().first.timeout(
        const Duration(seconds: 5),
      );
      expect(sample.up, greaterThanOrEqualTo(0));
      expect(sample.down, greaterThanOrEqualTo(0));
    });
  });
}
