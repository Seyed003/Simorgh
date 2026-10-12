import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../profiles/application/profiles_controller.dart';
import '../application/speed_controller.dart';

/// Last download speed of one profile, shown under its details. Empty until
/// the server has been speed tested.
class SpeedBadge extends ConsumerWidget {
  const SpeedBadge({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measuring = ref.watch(
      speedProvider.select((s) => s.current == profileId),
    );
    final result = ref.watch(speedProvider.select((s) => s.results[profileId]));
    if (!measuring && result == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final style = context.theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final Widget content;
    if (measuring) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 6),
          Text(l10n.speedTesting, style: style),
        ],
      );
    } else {
      final speed = result!.bytesPerSecond;
      final color = speed == null
          ? StatusColors.of(context).error
          : context.colors.primary;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_rounded, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            speed == null
                ? l10n.speedFailed
                : formatMbps(speed, locale: context.localeCode),
            textDirection: speed == null ? null : TextDirection.ltr,
            style: style?.copyWith(color: color),
          ),
        ],
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 2), child: content);
  }
}

/// Progress of a speed run with a stop button; hidden when idle.
class SpeedTestBanner extends ConsumerWidget {
  const SpeedTestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedProvider);
    if (!state.running) return const SizedBox.shrink();
    final l10n = context.l10n;
    final locale = context.localeCode;
    final name = ref.watch(
      profilesProvider.select(
        (s) => s.value?.profiles
            .where((p) => p.id == state.current)
            .firstOrNull
            ?.name,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.download_rounded, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.speedTestProgress(
                        formatNumber(state.done + 1, locale: locale),
                        formatNumber(state.total, locale: locale),
                      ),
                      style: context.theme.textTheme.labelLarge,
                    ),
                    if (name != null)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: state.total == 0 ? null : state.done / state.total,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.stopTest,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: ref.read(speedProvider.notifier).cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
