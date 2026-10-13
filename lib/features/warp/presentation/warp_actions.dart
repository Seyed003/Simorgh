import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../application/warp_service.dart';
import '../data/warp_client.dart';

/// Adding a free WARP config and finding endpoints for it.
class WarpActions {
  const WarpActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  Future<void> add() async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.warpAdd,
      message: l10n.warpExplain,
      confirmLabel: l10n.add,
    );
    if (!ok || !context.mounted) return;
    final service = ref.read(warpServiceProvider);
    final WarpAccount account;
    try {
      account = await withProgress(context, service.register);
    } on WarpException catch (e) {
      if (context.mounted) context.showSnack(l10n.warpFailed(e.message));
      return;
    }
    if (!context.mounted) return;
    final base = account.config();
    final best = await withProgress(context, () => service.bestEndpoint(base));
    final config = best ?? base;
    await ref
        .read(profilesProvider.notifier)
        .importText(account.link(host: config.server, port: config.port));
    if (!context.mounted) return;
    context.showSnack(
      best == null
          ? l10n.warpAddedNoEndpoint
          : l10n.warpAdded('${config.server}:${config.port}'),
    );
  }

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
