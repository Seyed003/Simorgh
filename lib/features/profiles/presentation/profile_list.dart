import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/profiles_controller.dart';
import '../domain/profile.dart';
import '../domain/profiles_state.dart';
import '../domain/subscription.dart';
import 'import_actions.dart';
import 'profile_actions.dart';
import 'widgets/profile_tile.dart';
import 'widgets/subscription_header.dart';

/// Scrollable list of configs grouped by "manual" and subscriptions, with an
/// optional [header] sliver (the connection panel on narrow screens).
class ProfileList extends ConsumerWidget {
  const ProfileList({super.key, this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profilesProvider);
    final l10n = context.l10n;

    final slivers = <Widget>[
      if (header != null) SliverToBoxAdapter(child: header),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
          child: Row(
            children: [
              Text(
                l10n.configs,
                style: context.theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if ((async.value?.subscriptions ?? const []).isNotEmpty)
                IconButton(
                  tooltip: l10n.updateAllSubscriptions,
                  icon: const Icon(Icons.sync_rounded),
                  onPressed: () =>
                      ImportActions(context, ref).updateAllSubscriptions(),
                ),
            ],
          ),
        ),
      ),
    ];

    switch (async) {
      case AsyncData(:final value):
        if (value.profiles.isEmpty) {
          slivers.add(const SliverToBoxAdapter(child: _EmptyState()));
        } else {
          slivers.addAll(_groups(context, ref, value));
        }
      case AsyncError(:final error):
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
          ),
        );
      default:
        slivers.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
    }
    // Room for the floating action button.
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));

    return CustomScrollView(slivers: slivers);
  }

  List<Widget> _groups(
    BuildContext context,
    WidgetRef ref,
    ProfilesState state,
  ) {
    final l10n = context.l10n;
    final widgets = <Widget>[];

    SliverList tiles(List<Profile> profiles) => SliverList.builder(
      itemCount: profiles.length,
      itemBuilder: (context, i) {
        final profile = profiles[i];
        return ProfileTile(
          key: ValueKey(profile.id),
          profile: profile,
          selected: profile.id == state.selectedId,
          onTap: () => ref.read(profilesProvider.notifier).select(profile.id),
          onMore: () => showProfileActions(context, ref, profile),
        );
      },
    );

    final manual = state.manualProfiles();
    if (manual.isNotEmpty) {
      widgets
        ..add(
          SliverToBoxAdapter(
            child: GroupHeader(title: l10n.manualGroup, count: manual.length),
          ),
        )
        ..add(tiles(manual));
    }
    for (final subscription in state.subscriptions) {
      final profiles = state.profilesOf(subscription.id);
      widgets
        ..add(
          SliverToBoxAdapter(
            child: SubscriptionHeader(
              subscription: subscription,
              count: profiles.length,
              onAction: (action) =>
                  _onSubscriptionAction(context, ref, subscription, action),
            ),
          ),
        )
        ..add(tiles(profiles));
    }
    return widgets;
  }

  Future<void> _onSubscriptionAction(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
    SubscriptionAction action,
  ) async {
    final l10n = context.l10n;
    final controller = ref.read(profilesProvider.notifier);
    switch (action) {
      case SubscriptionAction.update:
        await ImportActions(context, ref).updateSubscription(subscription.id);
      case SubscriptionAction.rename:
        final name = await textInputDialog(
          context,
          title: l10n.rename,
          label: l10n.name,
          initialValue: subscription.name,
          validator: (v) => v.trim().isEmpty ? l10n.invalidValue : null,
        );
        if (name != null) {
          await controller.renameSubscription(subscription.id, name.trim());
        }
      case SubscriptionAction.delete:
        final ok = await confirmDialog(
          context,
          title: l10n.deleteConfirmTitle,
          message: l10n.deleteSubscriptionConfirm(subscription.name),
          confirmLabel: l10n.delete,
          destructive: true,
        );
        if (ok) await controller.deleteSubscription(subscription.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.travel_explore_rounded,
            size: 56,
            color: context.colors.outline,
          ),
          const SizedBox(height: 16),
          Text(l10n.noConfigs, style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l10n.noConfigsHint,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
