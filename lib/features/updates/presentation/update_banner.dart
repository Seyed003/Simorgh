import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/theme/glass.dart';
import '../../../core/utils/context_ext.dart';
import '../application/update_controller.dart';

/// "Version X is available" on the home screen.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(updateProvider.select((s) => s.available));
    if (release == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Glass(
        radius: 24,
        tint: context.colors.primary,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.system_update_rounded, color: context.colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.updateAvailable(release.version),
                    style: context.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.updateHint,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: ref.read(updateProvider.notifier).dismiss,
              child: Text(l10n.updateLater),
            ),
            FilledButton(
              onPressed: () =>
                  ref.read(systemBridgeProvider).openUrl(release.url),
              child: Text(l10n.updateDownload),
            ),
          ],
        ),
      ),
    );
  }
}
