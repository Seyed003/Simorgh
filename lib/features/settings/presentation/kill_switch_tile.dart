import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../connection/application/vpn_controller.dart';

/// Android's lockdown state, read from the running VPN.
final vpnLockdownProvider =
    FutureProvider.autoDispose<({bool alwaysOn, bool lockdown})?>((ref) {
      ref.watch(vpnControllerProvider.select((s) => s.isConnected));
      return ref.watch(systemBridgeProvider).vpnLockdown();
    });

/// "Block internet without VPN": Android only lets the user switch this on
/// (Always-on VPN + block connections without VPN) in its own settings, so
/// the row explains how, opens them and shows whether it is on.
class KillSwitchTile extends ConsumerWidget {
  const KillSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = StatusColors.of(context);
    final lockdown = ref.watch(vpnLockdownProvider).value;
    final (text, color) = switch (lockdown) {
      (lockdown: true, alwaysOn: _) => (l10n.killSwitchOn, status.good),
      (lockdown: false, alwaysOn: _) => (l10n.killSwitchOff, status.error),
      null => (l10n.killSwitchUnknown, null),
    };
    return ListTile(
      leading: const TileIcon(Icons.shield_rounded, TileIcon.red),
      title: Text(l10n.killSwitch),
      subtitle: Text(text, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final open = await confirmDialog(
          context,
          title: l10n.killSwitch,
          message: l10n.killSwitchSteps(l10n.appTitle),
          confirmLabel: l10n.openSettings,
        );
        if (open) {
          await ref.read(systemBridgeProvider).openVpnSettings();
          ref.invalidate(vpnLockdownProvider);
        }
      },
    );
  }
}
