import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../../settings/application/core_options_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/dns_presets.dart';
import '../../../core/singbox/builder/core_options.dart';
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
        .update((current) => restorableOptions(backup.coreOptions, current));
    final settings = _ref.read(settingsProvider.notifier);
    await settings.setThemeMode(backup.settings.themeMode);
    await settings.setLanguage(backup.settings.language);
    await settings.setSubscriptionUpdateHours(
      backup.settings.subscriptionUpdateHours,
    );
    return added;
  }
}

/// The connection settings a backup may bring: tuning such as DNS presets,
/// fragmentation, mux or the fingerprint. What decides which traffic skips
/// the tunnel or who may use it stays as it is on this device: per-app
/// lists (they name another device's apps anyway), the local proxy and its
/// password, strict routing, MTU. A backup file can come from anyone, and
/// these would quietly leak traffic while the app shows "connected". DNS
/// servers outside the presets and values outside the offered choices are
/// ignored for the same reason: a stranger's resolver would see every site.
CoreOptions restorableOptions(CoreOptions backup, CoreOptions current) {
  bool preset(List<DnsPreset> presets, String address) =>
      presets.any((p) => p.address == address);
  return current.copyWith(
    logLevel: CoreOptions.logLevels.contains(backup.logLevel)
        ? backup.logLevel
        : null,
    remoteDns: preset(remoteDnsPresets, backup.remoteDns)
        ? backup.remoteDns
        : null,
    directDns: preset(directDnsPresets, backup.directDns)
        ? backup.directDns
        : null,
    enableIpv6: backup.enableIpv6,
    tunStack: CoreOptions.tunStacks.contains(backup.tunStack)
        ? backup.tunStack
        : null,
    sniff: backup.sniff,
    defaultFingerprint:
        CoreOptions.fingerprints.contains(backup.defaultFingerprint)
        ? () => backup.defaultFingerprint
        : null,
    bypassIran: backup.bypassIran,
    tlsFragment: backup.tlsFragment,
    mux: backup.mux,
    muxProtocol: backup.muxProtocol,
    blockQuic: backup.blockQuic,
  );
}
