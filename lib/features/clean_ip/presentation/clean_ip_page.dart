import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/glass.dart';
import '../../connection/application/vpn_controller.dart';
import '../../connection/domain/vpn_state.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../application/clean_ip_controller.dart';
import '../data/clean_ip_scanner.dart';

/// Finds Cloudflare addresses the user's own connection can reach, and
/// turns one into a copy of [profile] that uses it.
class CleanIpPage extends ConsumerWidget {
  const CleanIpPage({super.key, this.profile});

  final Profile? profile;

  String get _host => profile?.config.tlsHost ?? 'speed.cloudflare.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeCode;
    final state = ref.watch(cleanIpProvider);
    final controller = ref.read(cleanIpProvider.notifier);
    final vpnOff = ref.watch(
      vpnControllerProvider.select((s) => s.status == VpnStatus.disconnected),
    );

    return GlassScaffold(
      appBar: AppBar(title: Text(l10n.cleanIpScan)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l10n.cleanIpHint,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.cleanIpTestingHost(_host),
            style: context.theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<CdnProvider>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CdnProvider.cloudflare,
                label: Text(l10n.cdnCloudflare),
              ),
              ButtonSegment(
                value: CdnProvider.arvan,
                label: Text(l10n.cdnArvan),
              ),
            ],
            selected: {state.provider},
            onSelectionChanged: state.running
                ? null
                : (s) => controller.choose(s.first),
          ),
          if (state.provider == CdnProvider.arvan)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.cdnArvanHint,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!vpnOff)
            Card(
              color: context.colors.errorContainer,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: context.colors.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.cleanIpDisconnectFirst,
                        style: TextStyle(
                          color: context.colors.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: ref
                          .read(vpnControllerProvider.notifier)
                          .disconnect,
                      child: Text(l10n.disconnect),
                    ),
                  ],
                ),
              ),
            )
          else if (state.running)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: state.total == 0 ? null : state.tested / state.total,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.cleanIpProgress(
                          formatNumber(state.tested, locale: locale),
                          formatNumber(state.total, locale: locale),
                          formatNumber(state.hits.length, locale: locale),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(l10n.stopTest),
                    ),
                  ],
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: () => controller.start(_host),
              icon: const Icon(Icons.radar_rounded),
              label: Text(l10n.cleanIpStart),
            ),
          const SizedBox(height: 16),
          if (state.hits.isEmpty && state.tested > 0 && !state.running)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.cleanIpNone, textAlign: TextAlign.center),
            ),
          for (final hit in state.hits)
            _HitTile(hit: hit, onTap: () => _showActions(context, ref, hit)),
        ],
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    CleanIpHit hit,
  ) async {
    final l10n = context.l10n;
    final profile = this.profile;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile != null)
              ListTile(
                leading: const Icon(Icons.add_link_rounded),
                title: Text(l10n.cleanIpUse),
                subtitle: Text(profile.name, maxLines: 1),
                onTap: () => Navigator.pop(context, 'use'),
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(l10n.copyIp),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'use':
        final added = await ref
            .read(profilesProvider.notifier)
            .addAndSelect(profile!.config.withAddress(hit.ip));
        if (context.mounted) context.showSnack(l10n.cleanIpCreated(added.name));
      case 'copy':
        await Clipboard.setData(ClipboardData(text: hit.ip));
        if (context.mounted) context.showSnack(l10n.copied);
    }
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final CleanIpHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final ms = hit.latencyMs;
    final color = ms < 300
        ? status.good
        : ms < 800
        ? status.connecting
        : status.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.dns_outlined, color: context.colors.onSurfaceVariant),
      title: Text(
        hit.ip,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
      subtitle: hit.colo == null ? null : Text(hit.colo!),
      trailing: Text(
        context.l10n.latencyMs(formatNumber(ms, locale: context.localeCode)),
        style: context.theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }
}
