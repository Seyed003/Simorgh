import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/utils/context_ext.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionHeader(l10n.appearance),
          _LabeledControl(
            icon: Icons.translate_rounded,
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
            icon: Icons.palette_outlined,
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
          const SizedBox(height: 16),
          _SectionHeader(l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.appTitle),
            subtitle: const Text('${AppInfo.name} · ${AppInfo.nameFa}'),
          ),
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: Text(l10n.coreVersion),
            trailing: const Text(AppInfo.singBoxVersion),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: Text(l10n.license),
            trailing: const Text(AppInfo.license),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: Text(l10n.sourceCode),
            subtitle: const Text(
              AppInfo.repositoryUrl,
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 8),
      child: Text(
        title,
        style: context.theme.textTheme.titleSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
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

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label, style: context.theme.textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
