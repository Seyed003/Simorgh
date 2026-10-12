import 'package:flutter/material.dart';

enum AppLanguage {
  fa(Locale('fa')),
  en(Locale('en'));

  const AppLanguage(this.locale);

  final Locale locale;

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => AppLanguage.fa);
}

/// User facing preferences of the app shell.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.fa,
    this.subscriptionUpdateHours = 12,
  });

  /// Choices for [subscriptionUpdateHours]; 0 turns auto-update off.
  static const subscriptionUpdateChoices = [0, 3, 6, 12, 24];

  final ThemeMode themeMode;
  final AppLanguage language;

  /// Subscriptions older than this are refreshed when the app starts or
  /// comes back to the foreground. 0 = never.
  final int subscriptionUpdateHours;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    int? subscriptionUpdateHours,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      subscriptionUpdateHours:
          subscriptionUpdateHours ?? this.subscriptionUpdateHours,
    );
  }
}
