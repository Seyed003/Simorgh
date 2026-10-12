import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/test_config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  const api = ClashApiOptions(port: 19099, secret: 's');
  const builder = TestConfigBuilder(options: CoreOptions(), clashApi: api);

  test('one outbound per server, endpoints separate, direct last', () {
    final config = builder.build({
      'a': LinkParser.parse(vlessReality),
      'b': LinkParser.parse(wireguard),
      'c': LinkParser.parse(hy2),
    });
    final outbounds = (config.json['outbounds']! as List)
        .cast<Map<String, Object?>>();
    final endpoints = (config.json['endpoints']! as List)
        .cast<Map<String, Object?>>();
    expect(outbounds.map((o) => o['tag']), ['t0', 't2', 'direct']);
    expect(endpoints.single['tag'], 't1');
    expect(config.tagToId, {'t0': 'a', 't1': 'b', 't2': 'c'});
    expect(config.json.containsKey('inbounds'), isFalse);
    final route = config.json['route']! as Map;
    expect(route['auto_detect_interface'], isTrue);
    expect((config.json['experimental']! as Map)['clash_api'], {
      'external_controller': '127.0.0.1:19099',
      'secret': 's',
    });
  });

  test('local ports expose servers as proxies for speed tests', () {
    final config = builder.build(
      {'a': LinkParser.parse(vlessReality), 'b': LinkParser.parse(hy2)},
      localPorts: {'b': 20001},
    );
    expect(config.json['inbounds'], [
      {
        'type': 'mixed',
        'tag': 'in-t1',
        'listen': '127.0.0.1',
        'listen_port': 20001,
      },
    ]);
    expect((config.json['route']! as Map)['rules'], [
      {
        'inbound': ['in-t1'],
        'outbound': 't1',
      },
    ]);
  });

  test('maps sing-box errors back to the blamed server', () {
    final config = builder.build({
      'a': LinkParser.parse(vlessReality),
      'b': LinkParser.parse(wireguard),
      'c': LinkParser.parse(hy2),
    });
    expect(
      config.idBlamedBy('FATAL[0000] initialize outbound[1]: bad key'),
      'c',
    );
    expect(
      config.idBlamedBy('initialize endpoint[0]: decode private key'),
      'b',
    );
    expect(
      config.idBlamedBy('decode config: outbounds[0].server_port: json'),
      'a',
    );
    // The trailing direct outbound and unknown indexes blame nobody.
    expect(config.idBlamedBy('initialize outbound[2]: x'), isNull);
    expect(config.idBlamedBy('initialize outbound[9]: x'), isNull);
    expect(config.idBlamedBy('listen tcp: address already in use'), isNull);
  });

  test(
    'sing-box accepts the test config for every fixture',
    skip: Platform.environment['SING_BOX_BIN'] == null
        ? 'set SING_BOX_BIN'
        : null,
    () async {
      final config = builder.build({
        for (final (i, link) in allValidLinks.indexed)
          '$i': LinkParser.parse(link),
      });
      final dir = await Directory.systemTemp.createTemp('test-config');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/c.json')
        ..writeAsStringSync(config.encode());
      final result = await Process.run(Platform.environment['SING_BOX_BIN']!, [
        'check',
        '-c',
        file.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    },
  );
}
