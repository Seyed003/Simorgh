import 'package:flutter/material.dart';

import '../../../../core/singbox/proxy_config.dart';
import '../../../../core/utils/context_ext.dart';
import '../../domain/profile.dart';

const _badges = {
  ProxyProtocol.vmess: 'VM',
  ProxyProtocol.vless: 'VL',
  ProxyProtocol.trojan: 'TR',
  ProxyProtocol.shadowsocks: 'SS',
  ProxyProtocol.hysteria2: 'H2',
  ProxyProtocol.hysteria: 'HY',
  ProxyProtocol.tuic: 'TU',
  ProxyProtocol.wireguard: 'WG',
  ProxyProtocol.ssh: 'SH',
  ProxyProtocol.anytls: 'AT',
  ProxyProtocol.socks: 'S5',
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onMore,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected
                      ? colors.primary
                      : colors.secondaryContainer,
                  child: Text(
                    _badges[config.protocol]!,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected
                          ? colors.onPrimary
                          : colors.onSecondaryContainer,
                    ),
                  ),
                ),
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
                          fontWeight: FontWeight.w600,
                          color: selected ? colors.onPrimaryContainer : null,
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
                          color: selected
                              ? colors.onPrimaryContainer.withValues(alpha: 0.8)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: colors.primary),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: onMore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
