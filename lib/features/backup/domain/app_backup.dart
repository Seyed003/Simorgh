import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../profiles/domain/profiles_state.dart';
import '../../settings/domain/app_settings.dart';

/// Everything needed to set the app up again on another device: configs,
/// subscriptions, connection settings and app preferences, as one JSON file.
class AppBackup {
  const AppBackup({
    required this.profiles,
    required this.coreOptions,
    required this.settings,
    required this.createdAt,
  });

  static const format = 'aghelan-ghiamat-backup';
  static const version = 1;

  final ProfilesState profiles;
  final CoreOptions coreOptions;
  final AppSettings settings;
  final DateTime createdAt;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': format,
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'profiles': profiles.toJson(),
    'coreOptions': coreOptions.toJson(),
    'settings': {
      'themeMode': settings.themeMode.name,
      'language': settings.language.name,
      'subscriptionUpdateHours': settings.subscriptionUpdateHours,
    },
  });

  /// Throws [FormatException] for anything that is not one of our backups.
  static AppBackup decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('not a backup file');
    }
    if (json is! Map || json['format'] != format) {
      throw const FormatException('not a backup file');
    }
    if (json['version'] is! int || (json['version'] as int) > version) {
      throw const FormatException('backup from a newer version of the app');
    }
    try {
      return _fromJson(json);
    } on TypeError {
      // A field of the wrong type: a damaged or hand-made file.
      throw const FormatException('not a backup file');
    }
  }

  static AppBackup _fromJson(Map<Object?, Object?> json) {
    final settings = (json['settings'] as Map?) ?? const {};
    const defaults = AppSettings();
    return AppBackup(
      profiles: ProfilesState.fromJson(
        ((json['profiles'] as Map?) ?? const {}).cast<String, Object?>(),
      ),
      coreOptions: CoreOptions.fromJson(
        ((json['coreOptions'] as Map?) ?? const {}).cast<String, Object?>(),
      ),
      settings: AppSettings(
        themeMode:
            ThemeMode.values.asNameMap()[settings['themeMode']] ??
            defaults.themeMode,
        language: AppLanguage.fromCode(settings['language'] as String?),
        subscriptionUpdateHours:
            AppSettings.subscriptionUpdateChoices.contains(
              settings['subscriptionUpdateHours'],
            )
            ? settings['subscriptionUpdateHours']! as int
            : defaults.subscriptionUpdateHours,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// `aghelan-backup-2026-10-12.json`
  String get fileName {
    final d = createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'aghelan-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }
}
