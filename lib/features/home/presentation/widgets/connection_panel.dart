import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../connection/domain/traffic.dart';
import '../../../connection/domain/vpn_state.dart';
import '../../../latency/presentation/latency_badge.dart';
import '../../../profiles/application/profiles_controller.dart';
import '../../../profiles/domain/profile.dart';
import '../../../profiles/presentation/widgets/profile_tile.dart';
import '../../../shell/app_shell.dart';
import 'connect_button.dart';

/// The phoenix orb with the connection status under it.
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({super.key, this.orbSize = 210});

  final double orbSize;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConnectButton(size: orbSize),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          style: context.theme.textTheme.headlineSmall!.copyWith(color: color),
          child: Text(statusText),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 22,
          child: state.isConnected && state.connectedSince != null
              ? _ConnectedTimer(since: state.connectedSince!)
              : Text(
                  switch (state.status) {
                    VpnStatus.disconnected => l10n.tapToConnect,
                    _ when state.findingServer => l10n.autoFinding,
                    _ => '',
                  },
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
        ),
      ],
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

/// The server in use; tap to pick another one.
class ActiveServerCard extends ConsumerWidget {
  const ActiveServerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAuto = ref.watch(
      profilesProvider.select((s) => s.value?.isAuto ?? false),
    );
    final connected = ref.watch(
      vpnControllerProvider.select((s) => s.isConnected),
    );
    final Profile? profile;
    final String label;
    if (isAuto) {
      final activeId = ref.watch(autoActiveProfileIdProvider).value;
      profile = ref
          .watch(profilesProvider)
          .value
          ?.profiles
          .where((p) => p.id == activeId)
          .firstOrNull;
      label = profile == null ? l10n.autoSelect : l10n.autoActive(profile.name);
    } else {
      profile = ref.watch(selectedProfileProvider);
      label = profile?.name ?? l10n.noActiveConfig;
    }
    final muted = context.theme.textTheme.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    return Glass(
      radius: 26,
      onTap: () => ref.read(appTabProvider.notifier).select(AppTab.servers),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        children: [
          isAuto
              ? AutoAvatar(hot: connected)
              : ProtocolAvatar(
                  protocol: profile?.config.protocol,
                  hot: connected,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.server, style: muted),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile != null)
                  Text(
                    profile.config.protocol.displayName,
                    textDirection: TextDirection.ltr,
                    style: muted,
                  ),
              ],
            ),
          ),
          if (profile != null) LatencyBadge(profileId: profile.id),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Live download and upload speeds.
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
            icon: Icons.arrow_downward_rounded,
            label: l10n.download,
            speed: formatSpeed(stats.downloadSpeed, locale: locale),
            total: formatBytes(stats.downloadTotal, locale: locale),
            color: context.colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SpeedTile(
            icon: Icons.arrow_upward_rounded,
            label: l10n.upload,
            speed: formatSpeed(stats.uploadSpeed, locale: locale),
            total: formatBytes(stats.uploadTotal, locale: locale),
            color: context.colors.tertiary,
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
    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              speed,
              textDirection: TextDirection.ltr,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            '${context.l10n.totalTraffic}: $total',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
