import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/platform/system_bridge.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/latency/application/latency_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/profile_sort.dart';
import 'package:aghelan_ghiamat/features/latency/application/speed_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/updates/data/update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aghelan_ghiamat/features/profiles/presentation/profile_list.dart';
import 'package:aghelan_ghiamat/features/home/presentation/widgets/connect_button.dart';
import 'package:aghelan_ghiamat/features/network/application/internet_reach.dart';
import 'package:aghelan_ghiamat/features/network/data/reach_probe.dart';
import 'package:aghelan_ghiamat/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../core/singbox/openvpn_fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

Future<void> openConfigs(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.dns_outlined));
  await tester.pumpAndSettle();
}

void main() {
  Future<(FakeVpnPlatform, ProviderContainer)> pump(
    WidgetTester tester, {
    String links = '',
    Size size = const Size(420, 900),
    SystemBridge system = const SystemBridge(),
    String latestRelease = 'v0.0.1',
    InternetReach reach = InternetReach.open,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await mockPreferences({'settings.language': 'en'});
    final platform = FakeVpnPlatform();
    final container = ProviderContainer(
      overrides: [
        reachProbeProvider.overrideWithValue(FakeReachProbe(reach)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
        systemBridgeProvider.overrideWithValue(system),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(
            MockClient(
              (_) async => http.Response(
                '{"tag_name":"$latestRelease","html_url":"https://x/r"}',
                200,
              ),
            ),
          ),
        ),
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

  testWidgets('explains what works on the national internet', (tester) async {
    final system = FakeSystemBridge()..shareable = true;
    final (_, container) = await pump(
      tester,
      system: system,
      reach: InternetReach.domesticOnly,
    );
    expect(find.text('Only Iranian sites are reachable'), findsOneWidget);

    await tester.tap(find.text('What works?'));
    await tester.pumpAndSettle();
    expect(find.text('DNS switched automatically'), findsOneWidget);
    expect(find.text('Go through a server inside Iran'), findsOneWidget);
    expect(find.text('ArvanCloud for CDN configs'), findsOneWidget);

    await tester.ensureVisible(find.text('Share the app'));
    await tester.tap(find.text('Share the app'));
    await tester.pump();
    expect(system.sharedApp, 1);

    await tester.ensureVisible(find.text('Check again'));
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Still only Iranian sites are reachable.'),
      findsOneWidget,
    );

    await tester.tap(find.text('What works?'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test configs'));
    await tester.tap(find.text('Test configs'));
    await tester.pumpAndSettle();
    expect(container.read(appTabProvider), AppTab.servers);
  });

  testWidgets('no banner on an open internet', (tester) async {
    await pump(tester);
    expect(find.text('Only Iranian sites are reachable'), findsNothing);
  });

  testWidgets('shows the empty state without configs', (tester) async {
    await pump(tester);
    expect(find.text('No configs yet'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);

    await tester.tap(find.byType(ConnectButton));
    await tester.pump();
    expect(find.text('Select a config first'), findsOneWidget);
  });

  testWidgets('lists configs and connects', (tester) async {
    final (platform, _) = await pump(tester, links: '$vlessReality\n$hy2');
    // Home shows the selected server; the list is on its own tab.
    expect(find.text('Reality 🇳🇱'), findsOneWidget);
    expect(find.text('HY2'), findsNothing);
    await openConfigs(tester);
    expect(find.text('HY2'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byType(ConnectButton));
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
    await openConfigs(tester);
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
    // The server card on the home tab follows.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Auto (fastest server)'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
  });

  testWidgets('wide layout shows panel and list side by side', (tester) async {
    await pump(tester, links: trojanBare, size: const Size(1280, 800));
    expect(find.byType(ConnectButton), findsOneWidget);
    expect(find.byType(ProfileList), findsOneWidget);
    // Card on the panel plus the tile in the list.
    expect(find.text('bare'), findsNWidgets(2));
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
    await openConfigs(tester);

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
    await openConfigs(tester);
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
    expect(find.text('Import a file (.ovpn, JSON…)'), findsOneWidget);
    expect(find.text('Cisco AnyConnect'), findsOneWidget);
  });

  testWidgets('the configs tab adds configs too', (tester) async {
    await pump(tester, links: trojanBare);
    await openConfigs(tester);
    await tester.tap(find.byTooltip('Add config'));
    await tester.pumpAndSettle();
    expect(find.text('Import from clipboard'), findsOneWidget);
  });

  testWidgets('a link opened from another app is added after asking', (
    tester,
  ) async {
    final system = FakeSystemBridge();
    final (_, container) = await pump(tester, system: system);
    system.shared.add(const SharedText(trojanBare));
    await tester.pumpAndSettle();
    expect(find.text('1 config found. Add it?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(container.read(profilesProvider).value!.profiles, hasLength(1));

    system.shared.add(const SharedText('not a config'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a newer release shows a banner until dismissed', (tester) async {
    await pump(tester, links: trojanBare, latestRelease: 'v99.0.0');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 99.0.0 is available'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Later'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('Version 99.0.0 is available'), findsNothing);
  });

  testWidgets('an opened .ovpn file asks for its login', (tester) async {
    final system = FakeSystemBridge();
    final (_, container) = await pump(tester, system: system);
    system.shared.add(const SharedText(ovpnProfile, name: 'Germany'));
    await tester.pumpAndSettle();
    expect(find.text('1 config found. Add it?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // auth-user-pass without the login: asked right away.
    expect(find.text('Username and password'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'bob');
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final config = container.read(profilesProvider).value!.profiles.single;
    expect(config.name, 'Germany 1');
    expect(config.config.needsLogin, isFalse);
    expect(config.config.outbound['username'], 'bob');
    expect(config.config.outbound['password'], 'pw');
  });
}
