import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/latency/application/latency_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/profile_sort.dart';
import 'package:aghelan_ghiamat/features/latency/application/speed_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  Future<(FakeVpnPlatform, ProviderContainer)> pump(
    WidgetTester tester, {
    String links = '',
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await mockPreferences({'settings.language': 'en'});
    final platform = FakeVpnPlatform();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
        trafficProvider.overrideWith(
          (ref) => Stream.value(
            const TrafficStats(
              uploadSpeed: 2048,
              downloadSpeed: 3 * 1024 * 1024,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (links.isNotEmpty) {
      await tester.runAsync(() async {
        await container.read(profilesProvider.future);
        await container.read(profilesProvider.notifier).importText(links);
      });
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AghelanApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (platform, container);
  }

  testWidgets('shows the empty state without configs', (tester) async {
    await pump(tester);
    expect(find.text('No configs yet'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await tester.pump();
    expect(find.text('Select a config first'), findsOneWidget);
  });

  testWidgets('lists configs and connects', (tester) async {
    final (platform, _) = await pump(tester, links: '$vlessReality\n$hy2');
    expect(find.text('Reality 🇳🇱'), findsWidgets);
    expect(find.text('HY2'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.requests.single.profileName, 'Reality 🇳🇱');
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('3 MB/s'), findsOneWidget);
    expect(find.text('2 KB/s'), findsOneWidget);

    // Tear down the periodic timer of the connection clock.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('auto tile switches to auto mode', (tester) async {
    final (_, container) = await pump(tester, links: '$vlessReality\n$hy2');
    expect(find.text('Auto (fastest server)'), findsOneWidget);
    expect(
      find.text(
        'Uses the fastest server and switches to another one if it stops working',
      ),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Auto (fastest server)'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(container.read(profilesProvider).value!.isAuto, isTrue);
    // Tile plus the active-config chip of the connection panel.
    expect(find.text('Auto (fastest server)'), findsNWidgets(2));
    expect(find.byIcon(Icons.bolt_rounded), findsNWidgets(2));
  });

  testWidgets('wide layout shows panel and list side by side', (tester) async {
    await pump(tester, links: trojanBare, size: const Size(1280, 800));
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('bare'), findsWidgets);
  });

  testWidgets('shows latency badges and sorts fastest first', (tester) async {
    final (_, container) = await pump(tester, links: '$vlessReality\n$hy2');
    final ids = container
        .read(profilesProvider)
        .value!
        .profiles
        .map((p) => p.id)
        .toList();
    await tester.runAsync(() async {
      final prefs = container.read(sharedPreferencesProvider);
      await prefs.setString(
        'latency.results',
        '{"${ids[0]}":{"f":"unreachable","t":1},"${ids[1]}":{"d":87,"t":1}}',
      );
      await prefs.setString('profiles.sort', 'latency');
    });
    container.invalidate(latencyProvider);
    container.invalidate(profileSortProvider);
    await tester.pumpAndSettle();

    expect(find.text('87 ms'), findsOneWidget);
    expect(find.text('Timeout'), findsOneWidget);
    final hy2Top = tester.getTopLeft(find.text('HY2')).dy;
    final realityTop = tester.getTopLeft(find.text('Reality 🇳🇱').last).dy;
    expect(hy2Top, lessThan(realityTop));
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
  });

  testWidgets('shows speed results and offers a speed test', (tester) async {
    final (_, container) = await pump(tester, links: '$vlessReality\n$hy2');
    final ids = container
        .read(profilesProvider)
        .value!
        .profiles
        .map((p) => p.id)
        .toList();
    await tester.runAsync(
      () => container
          .read(sharedPreferencesProvider)
          .setString(
            'speed.results',
            '{"${ids[0]}":{"b":3062500,"t":1},"${ids[1]}":{"f":"unreachable","t":1}}',
          ),
    );
    container.invalidate(speedProvider);
    await tester.pumpAndSettle();
    expect(find.text('24.5 Mbps'), findsOneWidget);
    expect(find.text('Speed test failed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Speed test'), findsOneWidget);
  });

  testWidgets('add sheet offers import options', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add config'));
    await tester.pumpAndSettle();
    expect(find.text('Import from clipboard'), findsOneWidget);
    expect(find.text('Add subscription'), findsOneWidget);
    expect(find.text('Import QR from image'), findsOneWidget);
  });
}
