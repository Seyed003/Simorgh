import 'dart:convert';

import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/usage/application/usage_controller.dart';
import 'package:aghelan_ghiamat/features/usage/presentation/usage_page.dart';
import 'package:aghelan_ghiamat/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  testWidgets('totals, day details and reset', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const mb = 1024 * 1024;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences({
            'usage.daily': jsonEncode({
              '2026-10-12': [10 * mb, 90 * mb],
              '2026-10-10': [1 * mb, 4 * mb],
              '2026-09-01': [5 * mb, 5 * mb],
            }),
          }),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: UsagePage(today: DateTime(2026, 10, 12, 15)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100 MB'), findsWidgets); // today
    expect(find.text('105 MB'), findsWidgets); // 7 and 30 days
    expect(find.text('Tap a day for details'), findsOneWidget);
    // September is outside the 30-day table.
    expect(find.text('Oct 10, 2026'), findsOneWidget);
    expect(find.text('Sep 1, 2026'), findsNothing);

    // The last column is today.
    await tester.tap(find.bySemanticsLabel('Oct 12, 2026, 100 MB'));
    await tester.pumpAndSettle();
    expect(find.text('Oct 12, 2026:'), findsOneWidget);
    expect(find.text('90 MB'), findsWidgets);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(container.read(usageProvider).days, isEmpty);
    expect(
      find.text(
        'Nothing recorded yet. Usage is counted while you are connected.',
      ),
      findsOneWidget,
    );
  });
}
