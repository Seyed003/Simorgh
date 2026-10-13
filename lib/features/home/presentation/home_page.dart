import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/phoenix.dart';
import '../../../core/theme/glass.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/presentation/add_config_sheet.dart';
import '../../profiles/presentation/profile_list.dart';
import '../../updates/presentation/update_banner.dart';
import 'widgets/connection_panel.dart';

/// The home tab: the phoenix orb, the server in use and live speeds. Wide
/// windows show the config list beside it.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (wide) {
      return SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Brand(),
                        SizedBox(height: 16),
                        ConnectionPanel(orbSize: 230),
                        SizedBox(height: 24),
                        UpdateBanner(),
                        ActiveServerCard(),
                        SizedBox(height: 12),
                        SpeedPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 16, 16, 16),
              child: SizedBox(
                width: 460,
                child: Glass(radius: 34, child: ProfileList()),
              ),
            ),
          ],
        ),
      );
    }

    final empty = ref.watch(
      profilesProvider.select((s) => s.value?.profiles.isEmpty ?? false),
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final orb = math.min(constraints.maxWidth * 0.56, 230.0);
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 16),
                  child: Column(
                    children: [
                      const _Brand(),
                      const Spacer(),
                      ConnectionPanel(orbSize: orb),
                      const Spacer(),
                      const UpdateBanner(),
                      if (empty)
                        const _EmptyCard()
                      else
                        const ActiveServerCard(),
                      const SizedBox(height: 12),
                      const SpeedPanel(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 0),
    child: Row(
      children: [
        PhoenixMark(
          size: 40,
          ring: true,
          ringColor: context.colors.primary.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.appTitle,
                style: context.theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              Text(
                context.l10n.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends ConsumerWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Glass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        children: [
          Text(
            l10n.noConfigs,
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noConfigsHint,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FireButton(
            icon: Icons.add_rounded,
            label: l10n.addConfig,
            onPressed: () => showAddConfigSheet(context, ref),
          ),
        ],
      ),
    );
  }
}
