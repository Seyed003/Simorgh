import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
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

  testWidgets('wide layout shows panel and list side by side', (tester) async {
    await pump(tester, links: trojanBare, size: const Size(1280, 800));
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('bare'), findsWidgets);
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
