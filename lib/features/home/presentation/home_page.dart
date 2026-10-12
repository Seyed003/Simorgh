import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../connection/application/vpn_controller.dart';
import '../../connection/domain/vpn_state.dart';
import '../../connection/presentation/vpn_error_text.dart';
import '../../profiles/presentation/add_config_sheet.dart';
import '../../profiles/presentation/profile_list.dart';
import '../../settings/presentation/settings_page.dart';
import '../../usage/presentation/usage_page.dart';
import 'widgets/connection_panel.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const wideLayoutBreakpoint = 840.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    ref.listen<VpnError?>(vpnControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        context.showSnack(vpnErrorText(context, next));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: l10n.usage,
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const UsagePage())),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddConfigSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addConfig),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= wideLayoutBreakpoint) {
              return const Row(
                children: [
                  SizedBox(
                    width: 400,
                    child: Center(
                      child: SingleChildScrollView(child: ConnectionPanel()),
                    ),
                  ),
                  VerticalDivider(width: 1),
                  Expanded(child: ProfileList()),
                ],
              );
            }
            return const ProfileList(header: ConnectionPanel());
          },
        ),
      ),
    );
  }
}
