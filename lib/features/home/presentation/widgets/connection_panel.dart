import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../connection/domain/traffic.dart';
import '../../../connection/domain/vpn_state.dart';
import '../../../profiles/application/profiles_controller.dart';
import 'connect_button.dart';

/// Connect button, status line, active config and live speeds.
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vpnControllerProvider);
    final l10n = context.l10n;
    final color = statusColor(context, state.status);
    final statusText = switch (state.status) {
      VpnStatus.disconnected => l10n.statusDisconnected,
      VpnStatus.connecting => l10n.statusConnecting,
      VpnStatus.connected => l10n.statusConnected,
      VpnStatus.disconnecting => l10n.statusDisconnecting,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ConnectButton(),
          Text(
            statusText,
            style: context.theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 22,
            child: state.isConnected && state.connectedSince != null
                ? _ConnectedTimer(since: state.connectedSince!)
                : Text(
                    state.status == VpnStatus.disconnected
                        ? l10n.tapToConnect
                        : '',
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const _ActiveProfileChip(),
          const SizedBox(height: 16),
          const SpeedPanel(),
        ],
      ),
    );
  }
}

class _ConnectedTimer extends StatefulWidget {
  const _ConnectedTimer({required this.since});

  final DateTime since;

  @override
  State<_ConnectedTimer> createState() => _ConnectedTimerState();
}

class _ConnectedTimerState extends State<_ConnectedTimer> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(
      context.l10n.connectedFor(
        formatDuration(elapsed, locale: context.localeCode),
      ),
      style: context.theme.textTheme.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _ActiveProfileChip extends ConsumerWidget {
  const _ActiveProfileChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(selectedProfileProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_rounded,
            size: 18,
            color: context.colors.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              profile?.name ?? context.l10n.noActiveConfig,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (profile != null) ...[
            const SizedBox(width: 8),
            Text(
              profile.config.protocol.displayName,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: context.colors.onSecondaryContainer.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SpeedPanel extends ConsumerWidget {
  const SpeedPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(trafficProvider).value ?? TrafficStats.zero;
    final l10n = context.l10n;
    final locale = context.localeCode;
    return Row(
      children: [
        Expanded(
          child: _SpeedTile(
            icon: Icons.arrow_upward_rounded,
            label: l10n.upload,
            speed: formatSpeed(stats.uploadSpeed, locale: locale),
            total: formatBytes(stats.uploadTotal, locale: locale),
            color: context.colors.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SpeedTile(
            icon: Icons.arrow_downward_rounded,
            label: l10n.download,
            speed: formatSpeed(stats.downloadSpeed, locale: locale),
            total: formatBytes(stats.downloadTotal, locale: locale),
            color: context.colors.primary,
          ),
        ),
      ],
    );
  }
}

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({
    required this.icon,
    required this.label,
    required this.speed,
    required this.total,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String speed;
  final String total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.theme.textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.labelMedium),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      speed,
                      textDirection: TextDirection.ltr,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    '${context.l10n.totalTraffic}: $total',
                    style: textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
