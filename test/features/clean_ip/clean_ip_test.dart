import 'dart:io';
import 'dart:math';

import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/clean_ip/application/clean_ip_controller.dart';
import 'package:aghelan_ghiamat/features/clean_ip/data/clean_ip_scanner.dart';
import 'package:aghelan_ghiamat/features/clean_ip/data/cloudflare_ranges.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

int _toInt(String ip) =>
    ip.split('.').map(int.parse).fold(0, (acc, o) => (acc << 8) | o);

/// Scanner with a scripted probe: every address whose last octet is even
/// works, with a latency derived from it.
CleanIpScanner _fakeScanner({int sampleSize = 40}) => CleanIpScanner(
  sampleSize: sampleSize,
  concurrency: 4,
  random: Random(7),
  probe: (ip, host) async {
    final last = int.parse(ip.split('.').last);
    return last.isEven
        ? CleanIpHit(ip: ip, latencyMs: 50 + last, colo: 'FRA')
        : null;
  },
);

void main() {
  group('config with a clean IP', () {
    test('keeps the domain for TLS and the Host header', () {
      final config = LinkParser.parse(vlessWs);
      expect(config.isCdnCandidate, isTrue);
      final copy = config.withAddress('104.16.1.2');
      expect(copy.server, '104.16.1.2');
      expect(copy.outbound['server'], '104.16.1.2');
      expect((copy.outbound['tls']! as Map)['server_name'], 'example.com');
      expect(
        ((copy.outbound['transport']! as Map)['headers']! as Map)['Host'],
        'ws.example.com',
      );
      expect(copy.name, 'My Server 1 · 104.16.1.2');
      // The stored config is untouched.
      expect(config.outbound['server'], 'example.com');
    });

    test('fills SNI and Host from the old address when missing', () {
      final config = LinkParser.parse(
        'vless://$uuid@cdn.example.org:443?security=tls&type=ws&path=%2Fx#cdn',
      );
      final copy = config.withAddress('172.64.0.9').outbound;
      expect((copy['tls']! as Map)['server_name'], 'cdn.example.org');
      expect(
        ((copy['transport']! as Map)['headers']! as Map)['Host'],
        'cdn.example.org',
      );
    });

    test('only CDN-style configs qualify', () {
      expect(LinkParser.parse(vlessReality).isCdnCandidate, isFalse);
      expect(LinkParser.parse(hy2).isCdnCandidate, isFalse);
      expect(LinkParser.parse(vmessWsTls).isCdnCandidate, isTrue);
      expect(
        LinkParser.parse('vless://$uuid@1.2.3.4:443?security=tls&type=ws#ip')
            .isCdnCandidate,
        isFalse,
      );
    });
  });

  test('ArvanCloud: every usable address of its small ranges, no more', () {
    final ips = CleanIpScanner.sample(
      5000,
      Random(2),
      ranges: CdnProvider.arvan.ranges,
    );
    // 1536 addresses, minus what looks like network/broadcast.
    expect(ips.length, lessThanOrEqualTo(1536));
    expect(ips.length, greaterThan(1400));
    expect(ips.toSet(), hasLength(ips.length));
    expect(
      ips.every(
        (ip) =>
            ip.startsWith('185.143.23') ||
            ip.startsWith('185.220.226.') ||
            ip.startsWith('193.176.240.'),
      ),
      isTrue,
    );
    expect(CdnProvider.arvan.probe, httpProbe);
    expect(CdnProvider.cloudflare.probe, traceProbe);
  });

  test('samples distinct addresses inside the Cloudflare ranges', () {
    final ips = CleanIpScanner.sample(500, Random(1));
    expect(ips.toSet(), hasLength(500));
    final ranges = [
      for (final cidr in cloudflareIpv4Ranges)
        (
          start: _toInt(cidr.split('/').first),
          size: 1 << (32 - int.parse(cidr.split('/').last)),
        ),
    ];
    final inRange = ips.where((ip) {
      final v = _toInt(ip);
      return ranges.any((r) => v >= r.start && v < r.start + r.size);
    });
    expect(inRange, hasLength(500));
    expect(
      ips.every((ip) => !ip.endsWith('.0') && !ip.endsWith('.255')),
      isTrue,
    );
    // The two biggest ranges (/13s) get most of the picks.
    final big = ips.where(
      (ip) => ip.startsWith('104.') || ip.startsWith('172.'),
    );
    expect(big.length, greaterThan(300));
  });

  test('controller keeps the fastest hits and can stop', () async {
    final container = ProviderContainer(
      overrides: [
        cleanIpScannerFactoryProvider.overrideWithValue(_fakeScanner),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(cleanIpProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(cleanIpProvider.notifier).start('example.com');
    while (container.read(cleanIpProvider).running) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final state = container.read(cleanIpProvider);
    expect(state.tested, 40);
    expect(state.hits, isNotEmpty);
    final latencies = state.hits.map((h) => h.latencyMs).toList();
    expect(latencies, orderedEquals([...latencies]..sort()));
  });

  test('controller scans ArvanCloud addresses once chosen', () async {
    final container = ProviderContainer(
      overrides: [
        cleanIpScannerFactoryProvider.overrideWithValue(_fakeScanner),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(cleanIpProvider, (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(cleanIpProvider.notifier)
      ..choose(CdnProvider.arvan);
    expect(container.read(cleanIpProvider).provider, CdnProvider.arvan);
    notifier.start('example.ir');
    while (container.read(cleanIpProvider).running) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final state = container.read(cleanIpProvider);
    expect(state.provider, CdnProvider.arvan);
    expect(state.hits, isNotEmpty);
    expect(
      state.hits.every(
        (h) =>
            h.ip.startsWith('185.143.23') ||
            h.ip.startsWith('185.220.226.') ||
            h.ip.startsWith('193.176.240.'),
      ),
      isTrue,
    );
  });

  testWidgets('scan and make a config from a result', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences({'settings.language': 'en'}),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
        cleanIpScannerFactoryProvider.overrideWithValue(
          () => _fakeScanner(sampleSize: 12),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(profilesProvider.future);
      await container.read(profilesProvider.notifier).importText(vlessWs);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AghelanApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.dns_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find clean Cloudflare IP'));
    await tester.pumpAndSettle();
    expect(find.text('Tested with example.com'), findsOneWidget);

    await tester.tap(find.text('Start scan'));
    await tester.pumpAndSettle();
    final first = container.read(cleanIpProvider).hits.first;
    expect(find.text(first.ip), findsOneWidget);

    await tester.tap(find.text(first.ip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a copy of the config with this IP'));
    await tester.pumpAndSettle();
    final selected = container.read(selectedProfileProvider)!;
    expect(selected.config.server, first.ip);
    expect(selected.name, 'My Server 1 · ${first.ip}');
  });

  testWidgets('asks to disconnect first', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = FakeVpnPlatform();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences({'settings.language': 'en'}),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
        trafficProvider.overrideWith((ref) => Stream.value(TrafficStats.zero)),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(profilesProvider.future);
      await container.read(profilesProvider.notifier).importText(vlessWs);
      container.listen(vpnControllerProvider, (_, _) {});
      await container.read(vpnControllerProvider.notifier).connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AghelanApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.dns_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find clean Cloudflare IP'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Disconnect first: the scan has to use your own internet, not the VPN.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start scan'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('trace probe', () {
    final binary = Platform.environment['SING_BOX_BIN'];
    final skip = binary == null || !File(binary).existsSync()
        ? 'set SING_BOX_BIN (used to make a test certificate)'
        : null;

    test(
      'talks TLS with the given SNI and reads the colo',
      skip: skip,
      () async {
        final pair = await Process.run(binary!, [
          'generate',
          'tls-keypair',
          'cdn.example.org',
        ]);
        final pem = pair.stdout as String;
        final certStart = pem.indexOf('-----BEGIN CERTIFICATE-----');
        final context = SecurityContext()
          ..useCertificateChainBytes(pem.substring(certStart).codeUnits)
          ..usePrivateKeyBytes(pem.substring(0, certStart).codeUnits);
        final server = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4,
          0,
          context,
        );
        addTearDown(() => server.close(force: true));
        final hosts = <String?>[];
        server.listen((request) {
          hosts.add(request.headers.host);
          request.response
            ..write(
              request.uri.path == '/cdn-cgi/trace'
                  ? 'fl=1\nh=${request.headers.host}\ncolo=TST\n'
                  : 'nope',
            )
            ..close();
        });

        final hit = await traceProbe(
          '127.0.0.1',
          'cdn.example.org',
          port: server.port,
          allowBadCertificate: true,
        );
        expect(hit, isNotNull);
        expect(hit!.colo, 'TST');
        expect(hosts.single, 'cdn.example.org');

        // ArvanCloud has no trace page: any answer of the edge counts.
        final arvan = await httpProbe(
          '127.0.0.1',
          'cdn.example.org',
          port: server.port,
          allowBadCertificate: true,
        );
        expect(arvan, isNotNull);
        expect(arvan!.colo, isNull);

        // A closed port fails quietly.
        final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = closed.port;
        await closed.close();
        expect(
          await traceProbe('127.0.0.1', 'cdn.example.org', port: port),
          isNull,
        );
      },
    );
  });
}
