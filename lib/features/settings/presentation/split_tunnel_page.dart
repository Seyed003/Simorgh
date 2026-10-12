import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/glass.dart';
import '../application/core_options_controller.dart';
import '../data/installed_apps.dart';

/// Per-app split tunneling (Android). Edits are kept locally and saved once
/// when the page closes, so a live connection restarts only once.
class SplitTunnelPage extends ConsumerStatefulWidget {
  const SplitTunnelPage({super.key});

  @override
  ConsumerState<SplitTunnelPage> createState() => _SplitTunnelPageState();
}

class _SplitTunnelPageState extends ConsumerState<SplitTunnelPage> {
  late PerAppMode _mode;
  late Set<String> _selected;
  var _query = '';
  var _showSystem = false;

  @override
  void initState() {
    super.initState();
    final options = ref.read(coreOptionsProvider);
    _mode = options.perAppMode;
    _selected = options.perAppPackages.toSet();
  }

  Future<void> _save() async {
    final options = ref.read(coreOptionsProvider);
    final packages = _selected.toList()..sort();
    if (options.perAppMode == _mode &&
        options.perAppPackages.join(',') == packages.join(',')) {
      return;
    }
    await ref
        .read(coreOptionsProvider.notifier)
        .update((o) => o.copyWith(perAppMode: _mode, perAppPackages: packages));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final apps = ref.watch(installedAppsProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: GlassScaffold(
        appBar: AppBar(
          title: Text(l10n.splitTunnel),
          actions: [
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  checked: _showSystem,
                  onTap: () => setState(() => _showSystem = !_showSystem),
                  child: Text(l10n.showSystemApps),
                ),
                PopupMenuItem(
                  onTap: () => setState(_selected.clear),
                  child: Text(l10n.clearSelection),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<PerAppMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PerAppMode.off,
                    label: Text(l10n.splitTunnelOff),
                  ),
                  ButtonSegment(
                    value: PerAppMode.include,
                    label: Text(l10n.splitTunnelInclude),
                  ),
                  ButtonSegment(
                    value: PerAppMode.exclude,
                    label: Text(l10n.splitTunnelExclude),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                switch (_mode) {
                  PerAppMode.off => l10n.splitTunnelOffHint,
                  PerAppMode.include => l10n.splitTunnelIncludeHint,
                  PerAppMode.exclude => l10n.splitTunnelExcludeHint,
                },
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                enabled: _mode != PerAppMode.off,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.searchApps,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            if (_mode != PerAppMode.off)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.appsSelected(
                      formatNumber(
                        _selected.length,
                        locale: context.localeCode,
                      ),
                    ),
                    style: context.theme.textTheme.labelMedium,
                  ),
                ),
              ),
            Expanded(
              child: switch (apps) {
                AsyncData(:final value) => _AppList(
                  apps: _visible(value),
                  selected: _selected,
                  enabled: _mode != PerAppMode.off,
                  onToggle: (pkg, on) => setState(
                    () => on ? _selected.add(pkg) : _selected.remove(pkg),
                  ),
                ),
                AsyncError(:final error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$error', textAlign: TextAlign.center),
                  ),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Selected apps first, then the rest; system apps only on request
  /// (or when already selected).
  List<InstalledApp> _visible(List<InstalledApp> apps) {
    final query = _query.toLowerCase();
    final visible = apps.where((a) {
      if (a.system && !_showSystem && !_selected.contains(a.packageName)) {
        return false;
      }
      return query.isEmpty ||
          a.label.toLowerCase().contains(query) ||
          a.packageName.toLowerCase().contains(query);
    });
    return [
      ...visible.where((a) => _selected.contains(a.packageName)),
      ...visible.where((a) => !_selected.contains(a.packageName)),
    ];
  }
}

class _AppList extends StatelessWidget {
  const _AppList({
    required this.apps,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<InstalledApp> apps;
  final Set<String> selected;
  final bool enabled;
  final void Function(String packageName, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, i) {
        final app = apps[i];
        return CheckboxListTile(
          key: ValueKey(app.packageName),
          enabled: enabled,
          value: selected.contains(app.packageName),
          onChanged: (v) => onToggle(app.packageName, v ?? false),
          secondary: _AppIcon(app.packageName),
          title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            app.packageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: context.theme.textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

class _AppIcon extends ConsumerWidget {
  const _AppIcon(this.packageName);

  final String packageName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(appIconProvider(packageName)).value;
    return SizedBox.square(
      dimension: 36,
      child: bytes == null
          ? Icon(Icons.android_rounded, color: context.colors.outline)
          : Image.memory(bytes, gaplessPlayback: true),
    );
  }
}
