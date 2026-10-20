import 'package:aghelan_ghiamat/core/platform/system_bridge.dart';
import 'package:aghelan_ghiamat/features/settings/presentation/battery_tile.dart';
import 'package:aghelan_ghiamat/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

void main() {
  test('the provider reports the exemption state', () async {
    Future<bool?> read(bool? battery) async {
      final c = ProviderContainer(
        overrides: [
          systemBridgeProvider.overrideWithValue(
            FakeSystemBridge()..battery = battery,
          ),
        ],
      );
      addTearDown(c.dispose);
      return c.read(batteryUnrestrictedProvider.future);
    }

    expect(await read(true), isTrue);
    expect(await read(false), isFalse);
    expect(await read(null), isNull);
  });

  testWidgets('a restricted app offers to ask the OS; tapping asks it', (
    tester,
  ) async {
    final bridge = FakeSystemBridge()..battery = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [systemBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: BatteryTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Restricted: tap to let it stay connected in the background'),
      findsOneWidget,
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(bridge.batteryRequests, 1);
  });

  testWidgets('an exempt app shows it is on and is not tappable', (
    tester,
  ) async {
    final bridge = FakeSystemBridge()..battery = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [systemBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: BatteryTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    await tester.tap(find.byType(ListTile), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(bridge.batteryRequests, 0);
  });
}
