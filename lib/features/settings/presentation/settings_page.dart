import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/phoenix_image.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/platform/system_bridge.dart';
import '../../../core/theme/glass.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../backup/presentation/backup_actions.dart';
import '../../logs/presentation/logs_page.dart';
import '../../network/presentation/share_app.dart';
import '../../updates/application/update_controller.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';
import 'connection_settings.dart';

/// The settings tab: grouped glass lists in the iOS style.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        LargeTitle(title: l10n.settings),
        SectionLabel(l10n.appearance),
        GlassGroup(
          children: [
            _LabeledControl(
              icon: const TileIcon(Icons.translate_rounded, TileIcon.blue),
              label: l10n.language,
              child: SegmentedButton<AppLanguage>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppLanguage.fa,
                    label: Text(l10n.languagePersian),
                  ),
                  ButtonSegment(
                    value: AppLanguage.en,
                    label: Text(l10n.languageEnglish),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (s) => controller.setLanguage(s.first),
              ),
            ),
            _LabeledControl(
              icon: const TileIcon(Icons.palette_rounded, TileIcon.purple),
              label: l10n.theme,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l10n.themeDark),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => controller.setThemeMode(s.first),
              ),
            ),
          ],
        ),
        SectionLabel(l10n.subscriptions),
        GlassGroup(
          children: [
            ListTile(
              leading: const TileIcon(Icons.update_rounded, TileIcon.green),
              title: Text(l10n.autoUpdateSubscriptions),
              subtitle: Text(l10n.autoUpdateSubscriptionsHint),
              trailing: DropdownButton<int>(
                value: settings.subscriptionUpdateHours,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(16),
                items: [
                  for (final hours in AppSettings.subscriptionUpdateChoices)
                    DropdownMenuItem(
                      value: hours,
                      child: Text(
                        hours == 0
                            ? l10n.disabled
                            : l10n.everyHours(
                                formatNumber(hours, locale: context.localeCode),
                              ),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) controller.setSubscriptionUpdateHours(v);
                },
              ),
            ),
          ],
        ),
        SectionLabel(l10n.connectionSettings),
        const ConnectionSettingsSection(),
        SectionLabel(l10n.tools),
        GlassGroup(
          children: [
            ListTile(
              leading: const TileIcon(Icons.save_alt_rounded, TileIcon.blue),
              title: Text(l10n.backupSave),
              subtitle: Text(l10n.backupSaveHint),
              onTap: () => BackupActions(context, ref).save(),
            ),
            ListTile(
              leading: const TileIcon(Icons.restore_rounded, TileIcon.teal),
              title: Text(l10n.backupRestore),
              subtitle: Text(l10n.backupRestoreHint),
              onTap: () => BackupActions(context, ref).restore(),
            ),
            if (ref.read(systemBridgeProvider).canShareApp)
              const ShareAppTile(),
            ListTile(
              leading: const TileIcon(
                Icons.receipt_long_rounded,
                TileIcon.gray,
              ),
              title: Text(l10n.logs),
              subtitle: Text(l10n.logsHint),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const LogsPage())),
            ),
          ],
        ),
        SectionLabel(l10n.about),
        const _AboutCard(),
        const SizedBox(height: 12),
        GlassGroup(
          children: [
            ListTile(
              leading: const TileIcon(Icons.tag_rounded, TileIcon.gray),
              title: Text(l10n.version),
              subtitle: Text(l10n.updateCheck),
              trailing: const Text(AppInfo.version),
              onTap: () => _checkForUpdates(context, ref),
            ),
            ListTile(
              leading: const TileIcon(Icons.memory_rounded, TileIcon.indigo),
              title: Text(l10n.coreVersion),
              trailing: const Text(AppInfo.singBoxVersion),
            ),
            ListTile(
              leading: const TileIcon(Icons.gavel_rounded, TileIcon.gold),
              title: Text(l10n.license),
              trailing: const Text(AppInfo.license),
            ),
            ListTile(
              leading: const TileIcon(Icons.code_rounded, TileIcon.teal),
              title: Text(l10n.sourceCode),
              subtitle: const Text(
                AppInfo.repositoryUrl,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  try {
    final release = await withProgress(
      context,
      () => ref.read(updateProvider.notifier).check(),
    );
    if (!context.mounted) return;
    if (release == null) {
      context.showSnack(l10n.updateLatest);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.updateAvailable(release.version)),
          action: SnackBarAction(
            label: l10n.updateDownload,
            onPressed: () =>
                ref.read(systemBridgeProvider).openUrl(release.url),
          ),
        ),
      );
  } on Object {
    if (context.mounted) context.showSnack(l10n.updateFailed);
  }
}

/// The phoenix and what it stands for.
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Glass(
        blur: false,
        radius: 26,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          children: [
            const PhoenixImageMark(size: 92, glow: 0.5),
            const SizedBox(height: 10),
            Text(
              '${AppInfo.nameFa} · ${AppInfo.name}',
              textAlign: TextAlign.center,
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.tagline,
              textAlign: TextAlign.center,
              style: context.theme.textTheme.labelLarge?.copyWith(
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.brandStory,
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({
    required this.icon,
    required this.label,
    required this.child,
  });

  final Widget icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Text(label, style: context.theme.textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
