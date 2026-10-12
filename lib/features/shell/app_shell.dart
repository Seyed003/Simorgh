import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/phoenix.dart';
import '../../core/theme/glass.dart';
import '../../core/utils/context_ext.dart';
import '../connection/application/vpn_controller.dart';
import '../connection/domain/vpn_state.dart';
import '../connection/presentation/vpn_error_text.dart';
import '../home/presentation/home_page.dart';
import '../profiles/presentation/profile_list.dart';
import '../settings/presentation/settings_page.dart';
import '../usage/application/usage_controller.dart';
import '../usage/presentation/usage_page.dart';

enum AppTab { home, servers, usage, settings }

class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}

final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(
  AppTabNotifier.new,
);

/// The app frame: aurora backdrop, the four tabs, and a floating glass tab
/// bar (a side rail on wide windows).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static const wideLayoutBreakpoint = 840.0;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Tabs are built the first time they are opened, then kept alive.
  final _opened = <AppTab>{AppTab.home};

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(appTabProvider);
    _opened.add(tab);
    final connected = ref.watch(
      vpnControllerProvider.select((s) => s.isConnected),
    );
    // Counts daily usage while the app is open.
    ref.watch(usageRecorderProvider);
    ref.listen<VpnError?>(vpnControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        context.showSnack(vpnErrorText(context, next));
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppShell.wideLayoutBreakpoint;
        // The panels of a page share one backdrop blur; the tab bar, which
        // floats over scrolling content, blurs on its own.
        final pages = BackdropGroup(
          child: IndexedStack(
            index: tab.index,
            children: [
              for (final t in AppTab.values)
                _opened.contains(t) ? _page(t, wide) : const SizedBox.shrink(),
            ],
          ),
        );
        final bar = GlassTabBar(
          current: tab,
          vertical: wide,
          onSelect: ref.read(appTabProvider.notifier).select,
        );
        return AuroraBackground(
          warmth: connected ? 1 : 0,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: wide
                ? Row(
                    children: [
                      SafeArea(right: false, child: bar),
                      Expanded(child: pages),
                    ],
                  )
                : pages,
            bottomNavigationBar: wide ? null : bar,
          ),
        );
      },
    );
  }

  Widget _page(AppTab tab, bool wide) => switch (tab) {
    AppTab.home => HomePage(wide: wide),
    AppTab.servers => const SafeArea(bottom: false, child: ProfileList()),
    AppTab.usage => const SafeArea(bottom: false, child: UsagePage()),
    AppTab.settings => const SafeArea(bottom: false, child: SettingsPage()),
  };
}

/// Floating glass capsule with the tabs; a lens slides to the current one.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.current,
    required this.onSelect,
    this.vertical = false,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final bool vertical;

  static const _extent = 64.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      for (final tab in AppTab.values)
        _TabItem(
          tab: tab,
          label: switch (tab) {
            AppTab.home => l10n.home,
            AppTab.servers => l10n.configs,
            AppTab.usage => l10n.tabUsage,
            AppTab.settings => l10n.settings,
          },
          selected: tab == current,
          onTap: () => onSelect(tab),
        ),
    ];
    final index = current.index;

    if (vertical) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 0, 16),
        child: Center(
          child: Glass(
            radius: 34,
            shadow: true,
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              width: 76,
              height: _extent * items.length,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    top: _extent * index,
                    left: 0,
                    right: 0,
                    height: _extent,
                    child: const _Lens(),
                  ),
                  Column(
                    children: [
                      for (final item in items)
                        SizedBox(height: _extent, child: item),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Glass(
              radius: 36,
              shadow: true,
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                height: _extent,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth / items.length;
                    return Stack(
                      children: [
                        AnimatedPositionedDirectional(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          start: width * index,
                          top: 0,
                          bottom: 0,
                          width: width,
                          child: const _Lens(),
                        ),
                        Row(
                          children: [
                            for (final item in items) Expanded(child: item),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The brighter drop of glass under the current tab.
class _Lens extends StatelessWidget {
  const _Lens();

  @override
  Widget build(BuildContext context) => Glass(
    blur: false,
    radius: 30,
    tint: context.colors.primary,
    tintStrength: 0.14,
    child: const SizedBox.expand(),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.colors.primary
        : context.colors.onSurfaceVariant;
    final icon = switch (tab) {
      AppTab.home => TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 300),
        builder: (context, heat, _) =>
            PhoenixMark(size: 28, heat: heat, ash: color),
      ),
      AppTab.servers => Icon(
        selected ? Icons.dns_rounded : Icons.dns_outlined,
        color: color,
      ),
      AppTab.usage => Icon(
        selected ? Icons.insert_chart_rounded : Icons.insert_chart_outlined,
        color: color,
      ),
      AppTab.settings => Icon(
        selected ? Icons.settings_rounded : Icons.settings_outlined,
        color: color,
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 28, child: Center(child: icon)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
