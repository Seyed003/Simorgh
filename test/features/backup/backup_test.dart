import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/backup/application/backup_service.dart';
import 'package:aghelan_ghiamat/features/backup/domain/app_backup.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profile.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profiles_state.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/subscription.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:aghelan_ghiamat/features/settings/application/settings_controller.dart';
import 'package:aghelan_ghiamat/features/settings/domain/app_settings.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  Future<ProviderContainer> create() async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await mockPreferences({})),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final when = DateTime(2026, 10, 12, 9);
  final backupState = ProfilesState(
    profiles: [
      Profile(id: 'm1', config: LinkParser.parse(trojanBare), createdAt: when),
      Profile(
        id: 's1',
        config: LinkParser.parse(hy2),
        createdAt: when,
        subscriptionId: 'sub',
      ),
    ],
    subscriptions: const [
      Subscription(id: 'sub', name: 'Panel', url: 'https://panel.example/s'),
    ],
    selectedId: 's1',
  );

  test('a backup survives encoding; other files are refused', () {
    final backup = AppBackup(
      profiles: backupState,
      coreOptions: const CoreOptions(bypassIran: false, mixedPassword: 'pw'),
      settings: const AppSettings(
        themeMode: ThemeMode.dark,
        language: AppLanguage.en,
        subscriptionUpdateHours: 6,
      ),
      createdAt: when,
    );
    final decoded = AppBackup.decode(backup.encode());
    expect(decoded.profiles.toJson(), backupState.toJson());
    expect(decoded.coreOptions, backup.coreOptions);
    expect(decoded.settings.themeMode, ThemeMode.dark);
    expect(decoded.settings.language, AppLanguage.en);
    expect(decoded.settings.subscriptionUpdateHours, 6);
    expect(backup.fileName, 'aghelan-backup-2026-10-12.json');

    for (final bad in ['nope', '{}', '{"format":"other"}', '[1]']) {
      expect(() => AppBackup.decode(bad), throwsFormatException);
    }
    expect(
      () =>
          AppBackup.decode('{"format":"aghelan-ghiamat-backup","version":99}'),
      throwsFormatException,
    );
  });

  test('restore adds what is missing and takes over settings', () async {
    final c = await create();
    await c.read(profilesProvider.future);
    // Already here: the manual trojan config.
    await c.read(profilesProvider.notifier).importText(trojanBare);
    final service = c.read(backupServiceProvider);
    final backup = AppBackup(
      profiles: backupState,
      coreOptions: const CoreOptions(tlsFragment: TlsFragmentMode.tcp),
      settings: const AppSettings(language: AppLanguage.en),
      createdAt: when,
    );

    expect(await service.restore(backup), 1);
    final state = c.read(profilesProvider).value!;
    expect(state.profiles, hasLength(2));
    expect(state.subscriptions.single.url, 'https://panel.example/s');
    final restored = state.profiles.last;
    expect(restored.subscriptionId, state.subscriptions.single.id);
    expect(restored.id, isNot('s1'));
    // The device already had a selection.
    expect(state.selectedId, state.profiles.first.id);
    expect(c.read(coreOptionsProvider).tlsFragment, TlsFragmentMode.tcp);
    expect(c.read(settingsProvider).language, AppLanguage.en);

    // Restoring the same backup again adds nothing.
    expect(await service.restore(backup), 0);
    expect(c.read(profilesProvider).value!.profiles, hasLength(2));
  });

  test('restore on an empty device keeps the backup selection', () async {
    final c = await create();
    await c.read(profilesProvider.future);
    await c.read(profilesProvider.notifier).restore(backupState);
    final state = c.read(profilesProvider).value!;
    expect(state.selected?.name, LinkParser.parse(hy2).name);
  });
}
