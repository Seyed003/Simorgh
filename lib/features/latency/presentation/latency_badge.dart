import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../application/latency_controller.dart';
import '../domain/latency_result.dart';

/// Latency of one profile; tap to (re)test just that server.
class LatencyBadge extends ConsumerWidget {
  const LatencyBadge({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testing = ref.watch(
      latencyProvider.select((s) => s.testing.contains(profileId)),
    );
    final result = ref.watch(
      latencyProvider.select((s) => s.results[profileId]),
    );
    final l10n = context.l10n;
    final status = StatusColors.of(context);

    final Widget child;
    if (testing) {
      child = const SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (result == null) {
      child = Icon(
        Icons.network_ping_rounded,
        size: 18,
        color: context.colors.outline,
      );
    } else {
      final (text, color) = switch (result) {
        LatencyResult(:final delay?) => (
          l10n.latencyMs(formatNumber(delay, locale: context.localeCode)),
          delay < 300
              ? status.good
              : delay < 800
              ? status.connecting
              : status.error,
        ),
        LatencyResult(failure: LatencyFailure.unreachable) => (
          l10n.latencyTimeout,
          status.error,
        ),
        LatencyResult(failure: LatencyFailure.invalidConfig) => (
          l10n.latencyInvalid,
          status.error,
        ),
        _ => (l10n.latencyError, status.error),
      };
      child = Text(
        text,
        style: context.theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    return Tooltip(
      message: l10n.testServer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: testing
            ? null
            : () => ref.read(latencyProvider.notifier).test([profileId]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

/// "Test all" button that turns into progress + stop while a run is active.
class TestAllButton extends ConsumerWidget {
  const TestAllButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(latencyProvider);
    final l10n = context.l10n;
    final controller = ref.read(latencyProvider.notifier);
    if (!state.running) {
      return GlassIconButton(
        tooltip: l10n.testAll,
        icon: Icons.speed_rounded,
        onPressed: controller.testAll,
      );
    }
    final locale = context.localeCode;
    return Glass(
      radius: 22,
      padding: const EdgeInsetsDirectional.only(start: 14),
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.testProgress(
                formatNumber(state.done, locale: locale),
                formatNumber(state.total, locale: locale),
              ),
              style: context.theme.textTheme.labelMedium,
            ),
            IconButton(
              tooltip: l10n.stopTest,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: controller.cancel,
            ),
          ],
        ),
      ),
    );
  }
}
