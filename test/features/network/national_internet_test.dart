import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/platform/system_bridge.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/clean_ip/application/clean_ip_controller.dart';
import 'package:aghelan_ghiamat/features/clean_ip/data/clean_ip_scanner.dart';
import 'package:aghelan_ghiamat/features/clean_ip/presentation/clean_ip_page.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/network/application/internet_reach.dart';
import 'package:aghelan_ghiamat/features/network/data/reach_probe.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/shell/app_shell.dart';
import 'package:aghelan_ghiamat/features/updates/data/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  /// Pumps the whole app with the reach probe pinned to [reach]; returns the
  /// container so a test can drive the simulator and read navigation state.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    InternetReach reach = InternetReach.open,
    bool shareable = true,
  }) async {
    tester.view.physicalSize = const Size(440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // auto_reconnect off so the dead-tunnel watch leaves no pending timer.
    final prefs = await mockPreferences({
      'settings.language': 'en',
      'settings.auto_reconnect': false,
    });
    final container = ProviderContainer(
      overrides: [
        reachProbeProvider.overrideWithValue(FakeReachProbe(reach)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
        systemBridgeProvider.overrideWithValue(
          FakeSystemBridge()..shareable = shareable,
        ),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(
            MockClient(
              (_) async => http.Response(
                '{"tag_name":"v0.0.1","html_url":"https://x/r"}',
                200,
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AghelanApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the simulator shows and hides the national-internet banner', (
    tester,
  ) async {
    // The real probe says the internet is open, so no banner at first.
    final container = await pump(tester);
    expect(find.text('Only Iranian sites are reachable'), findsNothing);

    // Simulate the national internet: the banner appears.
    container
        .read(internetReachProvider.notifier)
        .simulate(InternetReach.domesticOnly);
    await tester.pumpAndSettle();
    expect(find.text('Only Iranian sites are reachable'), findsOneWidget);
    expect(container.read(internetReachProvider).domesticOnly, isTrue);

    // Hand control back: the probe says open again, the banner goes away.
    container.read(internetReachProvider.notifier).simulate(null);
    await tester.pumpAndSettle();
    expect(find.text('Only Iranian sites are reachable'), findsNothing);
    expect(container.read(internetReachProvider).simulated, isNull);
  });

  testWidgets('the relay step jumps to the servers tab', (tester) async {
    final container = await pump(tester, reach: InternetReach.domesticOnly);

    await tester.tap(find.text('What works?'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Go through a server inside Iran'));
    await tester.tap(find.text('Go through a server inside Iran'));
    await tester.pumpAndSettle();

    expect(container.read(appTabProvider), AppTab.servers);
  });

  testWidgets('the CDN step opens the clean-IP finder on ArvanCloud', (
    tester,
  ) async {
    final container = await pump(tester, reach: InternetReach.domesticOnly);

    await tester.tap(find.text('What works?'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ArvanCloud for CDN configs'));
    await tester.tap(find.text('ArvanCloud for CDN configs'));
    await tester.pumpAndSettle();

    expect(find.byType(CleanIpPage), findsOneWidget);
    expect(container.read(cleanIpProvider).provider, CdnProvider.arvan);
  });
}
