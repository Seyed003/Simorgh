import 'package:flutter/material.dart';

enum AppLanguage {
  fa(Locale('fa')),
  en(Locale('en'));

  const AppLanguage(this.locale);

  final Locale locale;

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => AppLanguage.fa);
}

/// User facing preferences of the app shell (look and language).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.fa,
  });

  final ThemeMode themeMode;
  final AppLanguage language;

  AppSettings copyWith({ThemeMode? themeMode, AppLanguage? language}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
    );
  }
}
