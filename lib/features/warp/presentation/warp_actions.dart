import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../application/warp_service.dart';

/// Finding a new endpoint for a WARP config.
class WarpActions {
  const WarpActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  Future<void> findEndpoint(Profile profile) async {
    final l10n = context.l10n;
    final best = await withProgress(
      context,
      () => ref.read(warpServiceProvider).bestEndpoint(profile.config),
    );
    if (!context.mounted) return;
    if (best == null) {
      context.showSnack(l10n.warpScanNone);
      return;
    }
    await ref.read(profilesProvider.notifier).replaceConfig(profile.id, best);
    if (context.mounted) {
      context.showSnack(l10n.warpScanDone('${best.server}:${best.port}'));
    }
  }
}
