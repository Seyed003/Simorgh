import 'package:flutter/material.dart';

import '../../../../core/branding/phoenix.dart';
import '../../../../core/singbox/proxy_config.dart';
import '../../../../core/theme/glass.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../latency/presentation/latency_badge.dart';
import '../../../latency/presentation/speed_badge.dart';
import '../../domain/profile.dart';

String _badge(ProxyProtocol protocol) => switch (protocol) {
  ProxyProtocol.vmess => 'VM',
  ProxyProtocol.vless => 'VL',
  ProxyProtocol.trojan => 'TR',
  ProxyProtocol.shadowsocks => 'SS',
  ProxyProtocol.hysteria2 => 'H2',
  ProxyProtocol.hysteria => 'HY',
  ProxyProtocol.tuic => 'TU',
  ProxyProtocol.wireguard => 'WG',
  ProxyProtocol.ssh => 'SH',
  ProxyProtocol.anytls => 'AT',
  ProxyProtocol.socks => 'S5',
  ProxyProtocol.openvpn => 'OV',
  ProxyProtocol.openconnect => 'AC',
};

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.onMore,
  });

  final Profile profile;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = profile.config;
    final summary = config.summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Glass(
        blur: false,
        radius: 22,
        tint: selected ? colors.primary : null,
        onTap: onTap,
        onLongPress: onMore,
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 0, 10),
        child: Row(
          children: [
            ProtocolAvatar(protocol: config.protocol, hot: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      config.protocol.displayName,
                      if (summary.isNotEmpty) summary,
                      '${config.server}:${config.port}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (config.isInsecure) const InsecureBadge(),
                  if (config.needsLogin) const LoginNeededBadge(),
                  SpeedBadge(profileId: profile.id),
                ],
              ),
            ),
            LatencyBadge(profileId: profile.id),
            if (selected)
              Icon(Icons.check_circle_rounded, color: colors.primary),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: colors.onSurfaceVariant,
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks a config that does not verify the server certificate.
class InsecureBadge extends StatelessWidget {
  const InsecureBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.of(context).error;
    return Tooltip(
      message: context.l10n.insecureHint,
      triggerMode: TooltipTriggerMode.tap,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gpp_maybe_rounded, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              context.l10n.insecure,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks an OpenVPN or Cisco config still missing its username and
/// password.
class LoginNeededBadge extends StatelessWidget {
  const LoginNeededBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.of(context).connecting;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            context.l10n.loginNeeded,
            style: context.theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Protocol initials on a squircle; [hot] fills it with fire.
class ProtocolAvatar extends StatelessWidget {
  const ProtocolAvatar({super.key, required this.protocol, this.hot = false});

  final ProxyProtocol? protocol;
  final bool hot;

  @override
  Widget build(BuildContext context) => _Avatar(
    hot: hot,
    child: switch (protocol) {
      null => const Icon(Icons.dns_rounded, size: 20),
      final protocol => Text(
        _badge(protocol),
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    },
  );
}

/// The avatar of "Auto (fastest server)".
class AutoAvatar extends StatelessWidget {
  const AutoAvatar({super.key, this.hot = false});

  final bool hot;

  @override
  Widget build(BuildContext context) =>
      _Avatar(hot: hot, child: const Icon(Icons.bolt_rounded, size: 22));
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.hot, required this.child});

  final bool hot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onSurface;
    final fg = hot ? Colors.white : ink;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 42,
      height: 42,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hot
              ? [phoenixFire[1], phoenixFire[2]]
              : [ink.withValues(alpha: 0.10), ink.withValues(alpha: 0.05)],
        ),
      ),
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: child,
          ),
        ),
      ),
    );
  }
}
