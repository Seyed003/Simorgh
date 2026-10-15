import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../domain/app_settings.dart';

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'settings.theme_mode';
  static const _languageKey = 'settings.language';
  static const _subscriptionUpdateKey = 'settings.subscription_update_hours';
  static const _autoReconnectKey = 'settings.auto_reconnect';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_themeKey),
        orElse: () => ThemeMode.system,
      ),
      language: AppLanguage.fromCode(prefs.getString(_languageKey)),
      subscriptionUpdateHours:
          prefs.getInt(_subscriptionUpdateKey) ??
          const AppSettings().subscriptionUpdateHours,
      autoReconnect:
          prefs.getBool(_autoReconnectKey) ??
          const AppSettings().autoReconnect,
    );
  }

  Future<void> setSubscriptionUpdateHours(int hours) async {
    state = state.copyWith(subscriptionUpdateHours: hours);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_subscriptionUpdateKey, hours);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_themeKey, mode.name);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_languageKey, language.name);
  }

  Future<void> setAutoReconnect(bool value) async {
    state = state.copyWith(autoReconnect: value);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_autoReconnectKey, value);
  }
}
