import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../application/profiles_controller.dart';
import '../domain/profile.dart';
import 'widgets/profile_tile.dart';

/// Puts [profile] behind another server: the traffic goes to that server
/// first and from there to [profile]'s. When the international internet is
/// cut, the first server is one inside Iran that still reaches abroad.
///
/// The chain is a new config; the originals stay as they are.
Future<void> chainProfile(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final l10n = context.l10n;
  final profiles = ref.read(profilesProvider).value?.profiles ?? const [];
  final candidates = [
    for (final p in profiles)
      if (p.id != profile.id && p.config.via == null) p,
  ];
  if (candidates.isEmpty) {
    context.showSnack(l10n.chainNoOther);
    return;
  }
  final first = await showModalBottomSheet<Profile>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                l10n.chainPickTitle,
                style: context.theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.chainPickHint(profile.name),
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in candidates)
                    ListTile(
                      leading: ProtocolAvatar(protocol: p.config.protocol),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${p.config.server}:${p.config.port}',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                      ),
                      onTap: () => Navigator.pop(context, p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (first == null || !context.mounted) return;
  final chained = profile.config
      .chainedVia(first.config)
      .copyWith(name: '${profile.name} ⟵ ${first.name}');
  await ref.read(profilesProvider.notifier).addAndSelect(chained);
  if (context.mounted) context.showSnack(l10n.chainCreated);
}
