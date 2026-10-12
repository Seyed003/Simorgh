import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  final instance = await mockPreferences(prefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
      child: const AghelanApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to Persian with right-to-left layout', (tester) async {
    await _pumpApp(tester, {});
    expect(find.text('عاقلان قیامت'), findsOneWidget);
    final direction = Directionality.of(tester.element(find.byType(Scaffold)));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('English is left-to-right', (tester) async {
    await _pumpApp(tester, {'settings.language': 'en'});
    expect(find.text('Aghelan Ghiamat'), findsOneWidget);
    final direction = Directionality.of(tester.element(find.byType(Scaffold)));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('dark theme preference is applied', (tester) async {
    await _pumpApp(tester, {'settings.theme_mode': 'dark'});
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
