import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../application/network_tuning.dart';
import 'smart_setup_page.dart';

/// Settings row: the current network and what is remembered for it.
class SmartSetupTile extends ConsumerWidget {
  const SmartSetupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final network = ref.watch(currentNetworkProvider).value;
    final tuning = ref.watch(networkTuningProvider);
    final remembered = network == null ? null : tuning.byNetwork[network.key];
    final status = remembered == null
        ? l10n.smartSetupNotTested
        : l10n.smartSetupRemembered(
            fragmentModeLabel(l10n, remembered.tlsFragment),
          );
    return ListTile(
      leading: const TileIcon(Icons.auto_fix_high_rounded, TileIcon.orange),
      title: Text(l10n.smartSetup),
      subtitle: Text(
        network == null
            ? status
            : '${networkLabel(context, network)} · $status',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SmartSetupPage())),
    );
  }
}
