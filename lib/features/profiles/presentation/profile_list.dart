import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/phoenix.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../application/profiles_controller.dart';
import '../domain/profile.dart';
import '../domain/profiles_state.dart';
import '../domain/subscription.dart';
import '../../latency/application/latency_controller.dart';
import '../../latency/application/profile_sort.dart';
import '../../latency/application/speed_controller.dart';
import '../../latency/presentation/latency_badge.dart';
import '../../latency/presentation/speed_badge.dart';
import 'add_config_sheet.dart';
import 'import_actions.dart';
import 'profile_actions.dart';
import 'widgets/auto_select_tile.dart';
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
        child: LargeTitle(
          title: l10n.configs,
          actions: [
            if ((async.value?.profiles ?? const []).isNotEmpty) ...[
              const TestAllButton(),
              const _SortButton(),
            ],
            if ((async.value?.subscriptions ?? const []).isNotEmpty)
              GlassIconButton(
                tooltip: l10n.updateAllSubscriptions,
                icon: Icons.sync_rounded,
                onPressed: () =>
                    ImportActions(context, ref).updateAllSubscriptions(),
              ),
            GlassIconButton(
              tooltip: l10n.addConfig,
              icon: Icons.add_rounded,
              onPressed: () => showAddConfigSheet(context, ref),
            ),
          ],
        ),
      ),
    ];

    switch (async) {
      case AsyncData(:final value):
        if (value.profiles.isEmpty) {
          slivers.add(const SliverToBoxAdapter(child: _EmptyState()));
        } else {
          slivers
            ..add(const SliverToBoxAdapter(child: SpeedTestBanner()))
            ..add(const SliverToBoxAdapter(child: AutoSelectTile()))
            ..addAll(_groups(context, ref, value));
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
    // Room for the floating tab bar.
    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
      ),
    );

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

    final sort = ref.watch(profileSortProvider);
    final results = ref.watch(latencyProvider.select((s) => s.results));
    List<Profile> sorted(List<Profile> list) =>
        sortProfiles(list, sort, results);

    final manual = sorted(state.manualProfiles());
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
      final profiles = sorted(state.profilesOf(subscription.id));
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
      case SubscriptionAction.test:
        final state = await ref.read(profilesProvider.future);
        await ref
            .read(latencyProvider.notifier)
            .test(state.profilesOf(subscription.id).map((p) => p.id));
      case SubscriptionAction.speedTest:
        // Skip servers the latency test already found dead.
        final state = await ref.read(profilesProvider.future);
        final latency = ref.read(latencyProvider).results;
        await ref
            .read(speedProvider.notifier)
            .test(
              state
                  .profilesOf(subscription.id)
                  .map((p) => p.id)
                  .where((id) => latency[id]?.ok ?? true),
            );
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

class _SortButton extends ConsumerWidget {
  const _SortButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(profileSortProvider);
    return GlassMenuButton<ProfileSort>(
      tooltip: l10n.sortBy,
      icon: Icons.sort_rounded,
      initialValue: current,
      onSelected: ref.read(profileSortProvider.notifier).set,
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: ProfileSort.defaultOrder,
          checked: current == ProfileSort.defaultOrder,
          child: Text(l10n.sortDefault),
        ),
        CheckedPopupMenuItem(
          value: ProfileSort.latency,
          checked: current == ProfileSort.latency,
          child: Text(l10n.sortLatency),
        ),
      ],
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          PhoenixMark(
            size: 72,
            heat: 0,
            ash: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noConfigs,
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noConfigsHint,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FireButton(
            icon: Icons.add_rounded,
            label: l10n.addConfig,
            onPressed: () => showAddConfigSheet(context, ref),
          ),
        ],
      ),
    );
  }
}
