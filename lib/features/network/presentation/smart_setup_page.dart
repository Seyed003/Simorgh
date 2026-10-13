import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/theme/glass.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/network_tuning.dart';
import '../application/smart_setup.dart';
import '../domain/network_identity.dart';

String fragmentModeLabel(AppLocalizations l10n, TlsFragmentMode mode) =>
    switch (mode) {
      TlsFragmentMode.off => l10n.fragmentOff,
      TlsFragmentMode.record => l10n.fragmentLight,
      TlsFragmentMode.tcp => l10n.fragmentStrong,
    };

String networkLabel(BuildContext context, NetworkIdentity network) {
  final l10n = context.l10n;
  return network.operatorLabel(context.localeCode) ??
      switch (network.kind) {
        NetworkKind.wifi => l10n.networkWifi,
        NetworkKind.cellular => l10n.networkMobile,
        NetworkKind.ethernet => l10n.networkEthernet,
        NetworkKind.desktop => l10n.networkThisComputer,
        NetworkKind.other => l10n.networkOther,
      };
}

IconData networkIcon(NetworkKind kind) => switch (kind) {
  NetworkKind.wifi => Icons.wifi_rounded,
  NetworkKind.cellular => Icons.signal_cellular_alt_rounded,
  NetworkKind.ethernet => Icons.settings_ethernet_rounded,
  NetworkKind.desktop => Icons.computer_rounded,
  NetworkKind.other => Icons.public_rounded,
};

/// Finds the TLS fragment mode that gets through the current network best
/// and remembers it for that network (operator, Wi-Fi, ...).
class SmartSetupPage extends ConsumerWidget {
  const SmartSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeCode;
    final setup = ref.watch(smartSetupProvider);
    final tuning = ref.watch(networkTuningProvider);
    final network = setup.network ?? ref.watch(currentNetworkProvider).value;
    final remembered = network == null ? null : tuning.byNetwork[network.key];
    final testing = setup.phase == SmartSetupPhase.testing;
    final muted = context.theme.textTheme.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    return GlassScaffold(
      appBar: AppBar(title: Text(l10n.smartSetup)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Glass(
            radius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Icon(
                  networkIcon(network?.kind ?? NetworkKind.other),
                  size: 36,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  network == null ? '…' : networkLabel(context, network),
                  style: context.theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  remembered == null
                      ? l10n.smartSetupNotTested
                      : l10n.smartSetupRemembered(
                          fragmentModeLabel(l10n, remembered.tlsFragment),
                        ),
                  style: muted,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.smartSetupHint,
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                const SizedBox(height: 16),
                if (testing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.smartSetupRunning(
                      formatNumber(
                        SmartSetupController.sampleSize,
                        locale: locale,
                      ),
                    ),
                    style: muted,
                  ),
                ] else
                  FireButton(
                    icon: Icons.auto_fix_high_rounded,
                    label: l10n.smartSetupStart,
                    onPressed: ref.read(smartSetupProvider.notifier).run,
                  ),
              ],
            ),
          ),
          if (switch (setup.phase) {
                SmartSetupPhase.done =>
                  network == null
                      ? null
                      : l10n.smartSetupDone(
                          networkLabel(context, network),
                          fragmentModeLabel(l10n, setup.chosen!),
                        ),
                SmartSetupPhase.noServers => l10n.smartSetupNoServers,
                SmartSetupPhase.nothingWorks => l10n.smartSetupNothingWorks,
                _ => null,
              }
              case final message?)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (setup.scores.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final score in setup.scores)
                  ListTile(
                    leading: Icon(
                      score.mode == setup.chosen
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: score.mode == setup.chosen
                          ? StatusColors.of(context).good
                          : context.colors.outline,
                    ),
                    title: Text(fragmentModeLabel(l10n, score.mode)),
                    subtitle: Text(
                      l10n.smartSetupScore(
                        formatNumber(score.ok, locale: locale),
                        formatNumber(score.total, locale: locale),
                      ),
                    ),
                    trailing: score.medianMs == null
                        ? null
                        : Text(
                            l10n.latencyMs(
                              formatNumber(score.medianMs!, locale: locale),
                            ),
                          ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          GlassGroup(
            margin: EdgeInsets.zero,
            children: [
              SwitchListTile(
                title: Text(l10n.smartSetupAuto),
                subtitle: Text(l10n.smartSetupAutoHint),
                value: tuning.autoSwitch,
                onChanged: ref
                    .read(networkTuningProvider.notifier)
                    .setAutoSwitch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
