import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../connection/application/vpn_controller.dart';
import '../../connection/domain/vpn_state.dart';
import '../../network/domain/network_identity.dart';
import '../../network/presentation/smart_setup_page.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profiles_state.dart';
import '../application/free_config.dart';
import '../application/free_servers.dart';
import '../data/warp_client.dart';

/// The "free connection" button: imports curated free public servers and
/// lets auto-select connect to the fastest, failing over by itself. If the
/// server lists can't be reached at all (operator blocks the CDN, offline),
/// it falls back to the free WARP route.
Future<void> getFreeConnection(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final free = ref.read(freeServersServiceProvider);

  // Public, untrusted servers: say so once before the first use.
  final firstTime = !await free.exists();
  if (!context.mounted) return;
  if (firstTime) {
    final ok = await confirmDialog(
      context,
      title: l10n.freeServersName,
      message: l10n.freeServersExplain,
      confirmLabel: l10n.freeConfigGo,
    );
    if (!ok || !context.mounted) return;
  }

  final status = ValueNotifier(l10n.freeServersFetching);
  final int count;
  try {
    count = await withProgress(
      context,
      status: status,
      () => free.ensure(name: l10n.freeServersName),
    );
  } on Object {
    // Couldn't reach any server list: fall back to the free WARP route.
    // The disclosure above already covered this, so don't ask again.
    if (context.mounted) await getFreeConfig(context, ref, askFirst: false);
    return;
  } finally {
    status.dispose();
  }
  if (!context.mounted) return;
  if (count <= 0) {
    await getFreeConfig(context, ref, askFirst: false);
    return;
  }

  context.showSnack(l10n.freeServersReady);
  // Auto-select measures them all, uses the fastest and fails over by itself.
  await ref.read(profilesProvider.notifier).select(ProfilesState.autoId);
  final vpn = ref.read(vpnControllerProvider);
  final controller = ref.read(vpnControllerProvider.notifier);
  if (vpn.status == VpnStatus.disconnected) {
    await controller.connect();
  } else {
    await controller.restart();
  }
}

/// The "free config" button: finds the fastest WARP route on the user's
/// operator, selects it and connects. [askFirst] is false when another flow
/// (the free-servers button falling back here) has already shown a disclosure.
Future<void> getFreeConfig(
  BuildContext context,
  WidgetRef ref, {
  bool askFirst = true,
}) async {
  final l10n = context.l10n;
  final service = ref.read(freeConfigServiceProvider);
  NetworkIdentity network;
  try {
    network = await ref.read(systemBridgeProvider).network();
  } on Object {
    network = const NetworkIdentity(kind: NetworkKind.other);
  }
  if (!context.mounted) return;
  // Explained once; afterwards the button just does it.
  if (askFirst && service.profileId == null) {
    final ok = await confirmDialog(
      context,
      title: l10n.freeConfigTitle(networkLabel(context, network)),
      message: l10n.freeConfigExplain,
      confirmLabel: l10n.freeConfigGo,
    );
    if (!ok || !context.mounted) return;
  }

  final status = ValueNotifier(l10n.freeConfigStepNetwork);
  final FreeConfigOutcome outcome;
  try {
    outcome = await withProgress(
      context,
      status: status,
      () => service.setUp(
        name: (n) => l10n.freeConfigName(networkLabel(context, n)),
        onStep: (step) => status.value = switch (step) {
          FreeConfigStep.network => l10n.freeConfigStepNetwork,
          FreeConfigStep.account => l10n.freeConfigStepAccount,
          FreeConfigStep.checking => l10n.freeConfigStepChecking,
          FreeConfigStep.scanning => l10n.freeConfigStepScanning(
            networkLabel(context, network),
          ),
        },
      ),
    );
  } on WarpException catch (e) {
    if (context.mounted) context.showSnack(l10n.warpFailed(e.message));
    return;
  } finally {
    status.dispose();
  }
  if (!context.mounted) return;

  final label = networkLabel(context, outcome.network);
  switch (outcome) {
    case FreeConfigUnreachable():
      context.showSnack(l10n.freeConfigUnreachable(label));
    case FreeConfigReady(:final profile):
      context.showSnack(l10n.freeConfigReady(label));
      final vpn = ref.read(vpnControllerProvider);
      final controller = ref.read(vpnControllerProvider.notifier);
      if (vpn.status == VpnStatus.disconnected) {
        await controller.connect();
      } else if (vpn.profileId == profile.id) {
        // Same config, new route: picking another one restarts by itself.
        await controller.restart();
      }
  }
}

/// The pill at the top of the home screen.
class FreeConfigButton extends ConsumerWidget {
  const FreeConfigButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.tonalIcon(
    icon: const Icon(Icons.card_giftcard_rounded, size: 18),
    label: Text(context.l10n.freeConfig),
    style: FilledButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 14),
    ),
    onPressed: () => getFreeConnection(context, ref),
  );
}
