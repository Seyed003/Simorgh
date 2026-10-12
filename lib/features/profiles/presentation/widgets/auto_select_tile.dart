import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../latency/presentation/latency_badge.dart';
import '../../application/profiles_controller.dart';
import '../../domain/profiles_state.dart';
import 'profile_tile.dart';

/// "Auto (fastest server)" entry above the config list. While connected in
/// auto mode it shows which server the core is currently using.
class AutoSelectTile extends ConsumerWidget {
  const AutoSelectTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final selected = ref.watch(
      profilesProvider.select((s) => s.value?.isAuto ?? false),
    );
    final activeId = selected
        ? ref.watch(autoActiveProfileIdProvider).value
        : null;
    final active = activeId == null
        ? null
        : ref
              .watch(profilesProvider)
              .value
              ?.profiles
              .where((p) => p.id == activeId)
              .firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Glass(
        blur: false,
        radius: 22,
        tint: selected ? colors.primary : null,
        onTap: () =>
            ref.read(profilesProvider.notifier).select(ProfilesState.autoId),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
        child: Row(
          children: [
            AutoAvatar(hot: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.autoSelect,
                    style: context.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active?.name ?? l10n.autoSelectHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (active != null) LatencyBadge(profileId: active.id),
            if (selected)
              Icon(Icons.check_circle_rounded, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
