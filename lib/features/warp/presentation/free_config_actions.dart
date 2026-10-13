import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../connection/application/vpn_controller.dart';
import '../../connection/domain/vpn_state.dart';
import '../../network/domain/network_identity.dart';
import '../../network/presentation/smart_setup_page.dart';
import '../application/free_config.dart';
import '../data/warp_client.dart';

/// The "free config" button: finds the fastest WARP route on the user's
/// operator, selects it and connects.
Future<void> getFreeConfig(BuildContext context, WidgetRef ref) async {
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
  if (service.profileId == null) {
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
    onPressed: () => getFreeConfig(context, ref),
  );
}
