import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../latency/presentation/latency_badge.dart';
import '../../application/profiles_controller.dart';
import '../../domain/profiles_state.dart';

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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              ref.read(profilesProvider.notifier).select(ProfilesState.autoId),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected
                      ? colors.primary
                      : colors.tertiaryContainer,
                  child: Icon(
                    Icons.bolt_rounded,
                    color: selected
                        ? colors.onPrimary
                        : colors.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.autoSelect,
                        style: context.theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected ? colors.onPrimaryContainer : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        active?.name ?? l10n.autoSelectHint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                              : colors.onSurfaceVariant,
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
        ),
      ),
    );
  }
}
