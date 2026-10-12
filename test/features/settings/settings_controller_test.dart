import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/settings/application/settings_controller.dart';
import 'package:aghelan_ghiamat/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

void main() {
  test('defaults to Persian and system theme', () async {
    final container = await createContainer();
    addTearDown(container.dispose);
    final settings = container.read(settingsProvider);
    expect(settings.language, AppLanguage.fa);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('persists changes', () async {
    final container = await createContainer();
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);
    await controller.setLanguage(AppLanguage.en);
    await controller.setThemeMode(ThemeMode.dark);

    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('settings.language'), 'en');
    expect(prefs.getString('settings.theme_mode'), 'dark');
    expect(container.read(settingsProvider).language, AppLanguage.en);
  });
}
