@Tags(['singbox'])
library;

import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/config_builder.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/protocols/openvpn.dart';
import 'package:aghelan_ghiamat/features/settings/domain/dns_presets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'openvpn_fixtures.dart';

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
    'hardened': SingBoxConfigBuilder(
      options: CoreOptions(
        tlsFragment: TlsFragmentMode.tcp,
        mux: true,
        muxProtocol: 'smux',
        perAppMode: PerAppMode.include,
        perAppPackages: ['org.telegram.messenger', 'com.android.chrome'],
      ),
      platform: CorePlatform.android,
      clashApi: ClashApiOptions(port: 19092, secret: 'z'),
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

  // OpenVPN profiles are files, not links.
  final profiles = {
    'seller': parseOpenVpn(ovpnProfile).withLogin('u', 'p'),
    'tls-crypt': parseOpenVpn(ovpnTlsCrypt),
  };
  for (final MapEntry(key: profile, value: proxy) in profiles.entries) {
    for (final MapEntry(key: name, value: builder) in variants.entries) {
      test('sing-box check OpenVPN $profile $name', skip: skip, () async {
        final file = File('${dir.path}/openvpn-$profile-$name.json');
        await file.writeAsString(builder.buildJson(proxy));
        final result = await Process.run(binary!, ['check', '-c', file.path]);
        expect(result.exitCode, 0, reason: '${result.stderr}${result.stdout}');
      });
    }
  }

  // Auto mode: every fixture at once behind a urltest group.
  for (final MapEntry(key: name, value: builder) in variants.entries) {
    test('sing-box check auto mode $name', skip: skip, () async {
      final proxies = [
        ...allValidLinks.map(LinkParser.parse),
        ...profiles.values,
      ];
      final file = File('${dir.path}/config-auto-$name.json');
      await file.writeAsString(builder.buildAutoJson(proxies));
      final result = await Process.run(binary!, ['check', '-c', file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}${result.stdout}');
    });
  }

  // Every DNS preset the settings offer must give a config the core accepts.
  for (final (i, (remote, direct)) in [
    for (final r in remoteDnsPresets)
      (r.address, directDnsPresets.first.address),
    for (final d in directDnsPresets)
      (remoteDnsPresets.first.address, d.address),
  ].indexed) {
    test('sing-box check DNS preset $remote + $direct', skip: skip, () async {
      final builder = SingBoxConfigBuilder(
        options: CoreOptions(remoteDns: remote, directDns: direct),
        platform: CorePlatform.android,
      );
      final file = File('${dir.path}/dns-$i.json');
      await file.writeAsString(builder.buildJson(LinkParser.parse(trojanTls)));
      final result = await Process.run(binary!, ['check', '-c', file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}${result.stdout}');
    });
  }

  test('sing-box check config moved to a clean IP', skip: skip, () async {
    final proxy = LinkParser.parse(vlessWs).withAddress('104.16.1.2');
    final file = File('${dir.path}/clean-ip.json');
    await file.writeAsString(variants['android']!.buildJson(proxy));
    final result = await Process.run(binary!, ['check', '-c', file.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}${result.stdout}');
  });
}
