import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_widgets.dart';

/// Whether the OS exempts the app from battery optimisation; `null` off
/// Android or when it cannot be read.
final batteryUnrestrictedProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(systemBridgeProvider).batteryUnrestricted(),
);

/// Android saves battery by killing background services, which silently drops
/// the tunnel — so auto-reconnect and always-on only hold if the app is
/// exempt. This row shows whether it is, and opens the system prompt to allow
/// it. The OS can only be asked, not forced, so (like the kill switch) it is a
/// status row, not a toggle.
class BatteryTile extends ConsumerWidget {
  const BatteryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = StatusColors.of(context);
    final unrestricted = ref.watch(batteryUnrestrictedProvider).value;
    final (text, color) = switch (unrestricted) {
      true => (l10n.batteryOn, status.good),
      false => (l10n.batteryOff, status.error),
      null => (l10n.batteryUnknown, null),
    };
    return ListTile(
      leading: const TileIcon(Icons.battery_saver_rounded, TileIcon.green),
      title: Text(l10n.batteryTitle),
      subtitle: Text(text, style: color == null ? null : TextStyle(color: color)),
      trailing: unrestricted == true
          ? Icon(Icons.check_circle_rounded, color: status.good)
          : const Icon(Icons.chevron_right_rounded),
      onTap: unrestricted == true
          ? null
          : () async {
              await ref.read(systemBridgeProvider).requestBatteryUnrestricted();
              ref.invalidate(batteryUnrestrictedProvider);
            },
    );
  }
}
