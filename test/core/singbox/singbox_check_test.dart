@Tags(['singbox'])
library;

import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// Validates every generated config with the real core:
///
///     SING_BOX_BIN=/path/to/sing-box flutter test --tags singbox
///
/// Skipped when SING_BOX_BIN is not set.
void main() {
  final binary = Platform.environment['SING_BOX_BIN'];
  final skip = binary == null || !File(binary).existsSync()
      ? 'set SING_BOX_BIN to a sing-box executable to run'
      : null;

  late Directory dir;
  setUpAll(
    () async => dir = await Directory.systemTemp.createTemp('singbox-check'),
  );
  tearDownAll(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  const variants = {
    'android': SingBoxConfigBuilder(
      options: CoreOptions(),
      platform: CorePlatform.android,
      clashApi: ClashApiOptions(port: 19090, secret: 'x'),
    ),
    'windows': SingBoxConfigBuilder(
      options: CoreOptions(
        enableIpv6: true,
        mixedPort: 2080,
        remoteDns: 'https://dns.google/dns-query',
        directDns: 'tls://dns.quad9.net',
      ),
      platform: CorePlatform.windows,
      clashApi: ClashApiOptions(port: 19091, secret: 'y'),
    ),
  };

  for (final (index, link) in allValidLinks.indexed) {
    for (final MapEntry(key: name, value: builder) in variants.entries) {
      test('sing-box check #$index $name', skip: skip, () async {
        final proxy = LinkParser.parse(link);
        final file = File('${dir.path}/config-$index-$name.json');
        await file.writeAsString(builder.buildJson(proxy));
        final result = await Process.run(binary!, ['check', '-c', file.path]);
        expect(
          result.exitCode,
          0,
          reason:
              '${proxy.protocol.name} ($link)\n${result.stderr}${result.stdout}',
        );
      });
    }
  }
}
