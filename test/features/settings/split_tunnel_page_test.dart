import 'dart:typed_data';

import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:aghelan_ghiamat/features/settings/data/installed_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import '../../helpers.dart';

class _FakeApps implements InstalledAppsSource {
  @override
  Future<List<InstalledApp>> list() async => const [
    InstalledApp(
      packageName: 'org.telegram.messenger',
      label: 'Telegram',
      system: false,
    ),
    InstalledApp(packageName: 'ir.bank.mobile', label: 'Bank', system: false),
    InstalledApp(
      packageName: 'com.android.phone',
      label: 'Phone',
      system: true,
    ),
  ];

  @override
  Future<Uint8List?> icon(String packageName) async => null;
}

void main() {
  testWidgets('picks apps and saves once on leaving', (tester) async {
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
        installedAppsSourceProvider.overrideWithValue(_FakeApps()),
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

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('All apps'), findsOneWidget);
    await tester.tap(find.text('Per-app proxy'));
    await tester.pumpAndSettle();

    // System apps are hidden until asked for.
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);

    await tester.tap(find.text('All but selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(find.text('1 apps selected'), findsOneWidget);
    // Nothing is saved while the page is open.
    expect(container.read(coreOptionsProvider).perAppMode, PerAppMode.off);

    await tester.enterText(find.byType(TextField), 'tele');
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsNothing);
    expect(find.text('Telegram'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final options = container.read(coreOptionsProvider);
    expect(options.perAppMode, PerAppMode.exclude);
    expect(options.perAppPackages, ['ir.bank.mobile']);
    expect(find.textContaining('All but selected'), findsOneWidget);
  });

  testWidgets('DNS presets replace typing', (tester) async {
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Direct DNS'));
    await tester.pumpAndSettle();
    expect(find.text('Shecan'), findsOneWidget);
    expect(find.text('Custom…'), findsOneWidget);
    await tester.tap(find.text('Shecan'));
    await tester.pumpAndSettle();
    expect(container.read(coreOptionsProvider).directDns, '178.22.122.100');

    await tester.tap(find.text('Remote DNS'));
    await tester.pumpAndSettle();
    expect(find.text('AdGuard · blocks ads'), findsOneWidget);
    await tester.tap(find.text('Custom…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://dns.example/q');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(coreOptionsProvider).remoteDns,
      'https://dns.example/q',
    );
  });
}
