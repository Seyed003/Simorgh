import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../../settings/application/core_options_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/app_backup.dart';

final backupServiceProvider = Provider<BackupService>(BackupService.new);

class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  Future<AppBackup> create() async => AppBackup(
    profiles: await _ref.read(profilesProvider.future),
    coreOptions: _ref.read(coreOptionsProvider),
    settings: _ref.read(settingsProvider),
    createdAt: DateTime.now(),
  );

  /// Adds the backup's configs and subscriptions to the current ones and
  /// takes over its settings. Returns the number of configs added.
  Future<int> restore(AppBackup backup) async {
    final added = await _ref
        .read(profilesProvider.notifier)
        .restore(backup.profiles);
    await _ref
        .read(coreOptionsProvider.notifier)
        .update((_) => backup.coreOptions);
    final settings = _ref.read(settingsProvider.notifier);
    await settings.setThemeMode(backup.settings.themeMode);
    await settings.setLanguage(backup.settings.language);
    await settings.setSubscriptionUpdateHours(
      backup.settings.subscriptionUpdateHours,
    );
    return added;
  }
}
