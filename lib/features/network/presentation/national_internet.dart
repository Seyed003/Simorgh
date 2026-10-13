import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/theme/glass.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../connection/application/vpn_controller.dart';
import '../../connection/domain/vpn_state.dart';
import '../../latency/application/latency_controller.dart';
import '../../shell/app_shell.dart';
import '../application/internet_reach.dart';
import '../data/reach_probe.dart';
import 'share_app.dart';

/// "Only Iranian sites are reachable" on the home screen, while the VPN is
/// off and the last check found the international link cut.
class NationalInternetBanner extends ConsumerWidget {
  const NationalInternetBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domesticOnly = ref.watch(
      internetReachProvider.select((s) => s.domesticOnly),
    );
    final vpnOff = ref.watch(
      vpnControllerProvider.select((s) => s.status == VpnStatus.disconnected),
    );
    if (!domesticOnly || !vpnOff) return const SizedBox.shrink();
    final l10n = context.l10n;
    final warn = StatusColors.of(context).connecting;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Glass(
        radius: 24,
        tint: warn,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.public_off_rounded, color: warn),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.nationalTitle,
                    style: context.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.nationalHint,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => showNationalInternetHelp(context, ref),
              child: Text(l10n.nationalHelp),
            ),
          ],
        ),
      ),
    );
  }
}

/// What still works on the national internet, with the matching tools.
Future<void> showNationalInternetHelp(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final canShare = ref.read(systemBridgeProvider).canShareApp;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  l10n.nationalSheetTitle,
                  style: sheet.theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Step(
                icon: Icons.dns_rounded,
                color: TileIcon.teal,
                title: l10n.nationalDns,
                text: l10n.nationalDnsHint,
              ),
              _Step(
                icon: Icons.alt_route_rounded,
                color: TileIcon.orange,
                title: l10n.nationalRelay,
                text: l10n.nationalRelayHint,
              ),
              _Step(
                icon: Icons.cloud_rounded,
                color: TileIcon.blue,
                title: l10n.nationalCdn,
                text: l10n.nationalCdnHint,
              ),
              _Step(
                icon: Icons.bluetooth_rounded,
                color: TileIcon.green,
                title: l10n.nationalOffline,
                text: l10n.nationalOfflineHint,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      unawaited(recheckInternet(context, ref));
                    },
                    child: Text(l10n.nationalRecheck),
                  ),
                  if (canShare)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.shareApp),
                      onPressed: () => shareTheApp(context, ref),
                    ),
                  FilledButton.icon(
                    icon: const Icon(Icons.speed_rounded),
                    label: Text(l10n.nationalTest),
                    onPressed: () {
                      Navigator.pop(sheet);
                      ref.read(appTabProvider.notifier).select(AppTab.servers);
                      unawaited(ref.read(latencyProvider.notifier).testAll());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Checks again and says how it went.
Future<void> recheckInternet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  await ref.read(internetReachProvider.notifier).check();
  if (!context.mounted) return;
  switch (ref.read(internetReachProvider).reach) {
    case InternetReach.domesticOnly:
      context.showSnack(l10n.nationalStillCut);
    case InternetReach.open:
      context.showSnack(l10n.nationalBack);
    case InternetReach.offline || null:
      break;
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: TileIcon(icon, color),
    title: Text(title),
    subtitle: Text(text),
  );
}
