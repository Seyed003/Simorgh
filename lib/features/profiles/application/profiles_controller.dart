import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/singbox/proxy_config.dart';
import '../../../core/singbox/subscription_info.dart';
import '../../../core/singbox/subscription_parser.dart';
import '../../../core/singbox/subscription_url.dart';
import '../data/profile_store.dart';
import '../data/subscription_client.dart';
import '../domain/profile.dart';
import '../domain/profiles_state.dart';
import '../domain/subscription.dart';

final profilesProvider =
    AsyncNotifierProvider<ProfilesController, ProfilesState>(
      ProfilesController.new,
    );

/// The profile the connect button will use.
final selectedProfileProvider = Provider<Profile?>(
  (ref) => ref.watch(profilesProvider).value?.selected,
);

const _uuid = Uuid();

class ProfilesController extends AsyncNotifier<ProfilesState> {
  ProfileStore get _store => ref.read(profileStoreProvider);

  @override
  Future<ProfilesState> build() => ref.watch(profileStoreProvider).load();

  Future<ProfilesState> _current() async => state.value ?? await future;

  Future<void> _commit(ProfilesState next) async {
    state = AsyncData(next);
    await _store.save(next);
  }

  /// Imports share links, base64 blobs, sing-box JSON or an OpenVPN
  /// profile from free text ([name]: the file it came from). A lone
  /// http(s) URL is treated as a subscription.
  Future<ImportOutcome> importText(String text, {String? name}) async {
    final trimmed = text.trim();
    if (subscriptionUri(trimmed) != null) {
      return addSubscription(trimmed, name: subscriptionNameOf(trimmed));
    }
    final result = SubscriptionParser.parse(trimmed, name: name);
    final current = await _current();
    final existing = current.manualProfiles().map(_fingerprint).toSet();
    final now = DateTime.now();
    final added = <Profile>[];
    for (final config in result.proxies) {
      if (!existing.add(_configFingerprint(config))) continue;
      added.add(Profile(id: _uuid.v4(), config: config, createdAt: now));
    }
    if (added.isNotEmpty) {
      await _commit(
        current.copyWith(
          profiles: [...current.profiles, ...added],
          selectedId: current.hasSelection ? null : () => added.first.id,
        ),
      );
    }
    return ImportOutcome(
      added: added.length,
      skipped: result.skipped.length,
      profiles: added,
      skipReason: result.skipped.firstOrNull?.reason,
    );
  }

  /// Adds the subscription at [url] (or an Outline `ssconf://` key).
  Future<ImportOutcome> addSubscription(String url, {String? name}) async {
    name ??= subscriptionNameOf(url);
    url = subscriptionUri(url)?.toString() ?? url.trim();
    final response = await ref.read(subscriptionClientProvider).fetch(url);
    final info = SubscriptionInfo.fromHeaders(response.headers);
    final result = SubscriptionParser.parse(response.body, name: name);
    if (result.proxies.isEmpty) {
      throw const SubscriptionException('no supported configs in subscription');
    }
    final subscription = Subscription(
      id: _uuid.v4(),
      name: _subscriptionName(name, info, url),
      url: url.trim(),
      info: info,
      lastUpdated: DateTime.now(),
    );
    final profiles = _profilesFor(subscription.id, result.proxies);
    final current = await _current();
    await _commit(
      current.copyWith(
        profiles: [...current.profiles, ...profiles],
        subscriptions: [...current.subscriptions, subscription],
        selectedId: current.hasSelection ? null : () => profiles.first.id,
      ),
    );
    return ImportOutcome(
      added: profiles.length,
      skipped: result.skipped.length,
      subscription: subscription,
      profiles: profiles,
    );
  }

  /// Re-downloads a subscription and replaces its profiles, keeping the
  /// selection on the same server when it still exists.
  Future<ImportOutcome> updateSubscription(String id) async {
    final current = await _current();
    final subscription = current.subscriptions.firstWhere((s) => s.id == id);
    final response = await ref
        .read(subscriptionClientProvider)
        .fetch(subscription.url);
    final result = SubscriptionParser.parse(
      response.body,
      name: subscription.name,
    );
    if (result.proxies.isEmpty) {
      throw const SubscriptionException('no supported configs in subscription');
    }
    final info = SubscriptionInfo.fromHeaders(response.headers);
    final old = current.profilesOf(id);
    final oldById = {for (final p in old) p.id: p};
    final oldIdByFingerprint = {for (final p in old) _fingerprint(p): p.id};

    // Reuse ids for unchanged servers so the selection survives updates.
    final fresh = <Profile>[];
    final now = DateTime.now();
    for (final config in result.proxies) {
      final reusedId = oldIdByFingerprint.remove(_configFingerprint(config));
      fresh.add(
        Profile(
          id: reusedId ?? _uuid.v4(),
          config: config,
          createdAt: reusedId != null ? oldById[reusedId]!.createdAt : now,
          subscriptionId: id,
        ),
      );
    }

    final others = current.profiles.where((p) => p.subscriptionId != id);
    final selectedGone =
        current.selectedId != null &&
        oldById.containsKey(current.selectedId) &&
        !fresh.any((p) => p.id == current.selectedId);
    await _commit(
      current.copyWith(
        profiles: [...others, ...fresh],
        subscriptions: [
          for (final s in current.subscriptions)
            if (s.id == id)
              s.copyWith(
                info: info,
                lastUpdated: now,
                name: info.title != null && s.name == _hostOf(s.url)
                    ? info.title
                    : null,
              )
            else
              s,
        ],
        selectedId: selectedGone ? () => fresh.first.id : null,
      ),
    );
    return ImportOutcome(added: fresh.length, skipped: result.skipped.length);
  }

  /// Updates every subscription, returning the names that failed.
  Future<List<String>> updateAllSubscriptions() async {
    final failures = <String>[];
    for (final s in (await _current()).subscriptions) {
      try {
        await updateSubscription(s.id);
      } on Exception {
        failures.add(s.name);
      }
    }
    return failures;
  }

  /// Adds [config] as a new manual profile and selects it.
  Future<Profile> addAndSelect(ProxyConfig config) async {
    final current = await _current();
    final profile = Profile(
      id: _uuid.v4(),
      config: config,
      createdAt: DateTime.now(),
    );
    await _commit(
      current.copyWith(
        profiles: [...current.profiles, profile],
        selectedId: () => profile.id,
      ),
    );
    return profile;
  }

  /// Refreshes every subscription last updated more than [maxAge] ago
  /// (or never) and returns the ids it tried, failures included.
  Future<Set<String>> updateDueSubscriptions(
    Duration maxAge, {
    Set<String> skip = const {},
    DateTime? now,
  }) async {
    final oldest = (now ?? DateTime.now()).subtract(maxAge);
    final due = [
      for (final s in (await _current()).subscriptions)
        if (!skip.contains(s.id) &&
            (s.lastUpdated == null || s.lastUpdated!.isBefore(oldest)))
          s.id,
    ];
    for (final id in due) {
      try {
        await updateSubscription(id);
      } on Exception {
        // Offline or the panel is down; the caller retries later.
      }
    }
    return due.toSet();
  }

  Future<void> select(String id) async {
    final current = await _current();
    await _commit(current.copyWith(selectedId: () => id));
  }

  Future<void> rename(String id, String name) async {
    final current = await _current();
    await _commit(
      current.copyWith(
        profiles: [
          for (final p in current.profiles)
            p.id == id ? p.copyWith(config: p.config.copyWith(name: name)) : p,
        ],
      ),
    );
  }

  Future<void> renameSubscription(String id, String name) async {
    final current = await _current();
    await _commit(
      current.copyWith(
        subscriptions: [
          for (final s in current.subscriptions)
            s.id == id ? s.copyWith(name: name) : s,
        ],
      ),
    );
  }

  Future<void> deleteProfile(String id) async {
    final current = await _current();
    final remaining = current.profiles.where((p) => p.id != id).toList();
    await _commit(
      current.copyWith(
        profiles: remaining,
        selectedId: _selectionAfterRemoval(current, remaining),
      ),
    );
  }

  /// Swaps the config of profile [id], e.g. a new WARP endpoint.
  Future<void> replaceConfig(String id, ProxyConfig config) async {
    final current = await _current();
    await _commit(
      current.copyWith(
        profiles: [
          for (final p in current.profiles)
            p.id == id ? p.copyWith(config: config) : p,
        ],
      ),
    );
  }

  /// Adds what a backup has and this device lacks: subscriptions by URL
  /// (with their configs) and manual configs by content. Everything gets
  /// fresh ids. Returns the number of configs added.
  Future<int> restore(ProfilesState backup) async {
    final current = await _current();
    final knownUrls = current.subscriptions.map((s) => s.url).toSet();
    final subscriptionIds = <String, String>{};
    final subscriptions = <Subscription>[];
    for (final s in backup.subscriptions) {
      if (!knownUrls.add(s.url)) continue;
      final id = _uuid.v4();
      subscriptionIds[s.id] = id;
      subscriptions.add(
        Subscription(
          id: id,
          name: s.name,
          url: s.url,
          info: s.info,
          lastUpdated: s.lastUpdated,
        ),
      );
    }
    final existing = current.manualProfiles().map(_fingerprint).toSet();
    final profileIds = <String, String>{};
    final added = <Profile>[];
    for (final p in backup.profiles) {
      if (!p.config.isConsistent) continue;
      final String? subscriptionId;
      if (p.subscriptionId == null) {
        if (!existing.add(_fingerprint(p))) continue;
        subscriptionId = null;
      } else {
        subscriptionId = subscriptionIds[p.subscriptionId];
        if (subscriptionId == null) continue;
      }
      final id = _uuid.v4();
      profileIds[p.id] = id;
      added.add(
        Profile(
          id: id,
          config: p.config,
          createdAt: p.createdAt,
          subscriptionId: subscriptionId,
        ),
      );
    }
    if (added.isEmpty && subscriptions.isEmpty) return 0;
    final restoredSelection = backup.isAuto
        ? ProfilesState.autoId
        : profileIds[backup.selectedId];
    await _commit(
      current.copyWith(
        profiles: [...current.profiles, ...added],
        subscriptions: [...current.subscriptions, ...subscriptions],
        selectedId: current.hasSelection
            ? null
            : () => restoredSelection ?? added.firstOrNull?.id,
      ),
    );
    return added.length;
  }

  Future<void> deleteSubscription(String id) async {
    final current = await _current();
    final remaining = current.profiles
        .where((p) => p.subscriptionId != id)
        .toList();
    await _commit(
      current.copyWith(
        profiles: remaining,
        subscriptions: current.subscriptions.where((s) => s.id != id).toList(),
        selectedId: _selectionAfterRemoval(current, remaining),
      ),
    );
  }

  /// Keeps the selection (auto mode included) while it still points at
  /// something; otherwise falls back to the first remaining profile.
  static String? Function()? _selectionAfterRemoval(
    ProfilesState current,
    List<Profile> remaining,
  ) {
    if (remaining.isEmpty) return () => null;
    if (current.isAuto) return null;
    if (remaining.any((p) => p.id == current.selectedId)) return null;
    return () => remaining.first.id;
  }

  List<Profile> _profilesFor(String subscriptionId, List<ProxyConfig> configs) {
    final now = DateTime.now();
    return [
      for (final c in configs)
        Profile(
          id: _uuid.v4(),
          config: c,
          createdAt: now,
          subscriptionId: subscriptionId,
        ),
    ];
  }

  static String _fingerprint(Profile p) => _configFingerprint(p.config);

  static String _configFingerprint(ProxyConfig c) =>
      '${c.name}|${jsonEncode(c.outbound)}'
      '${c.via == null ? '' : '|via ${_configFingerprint(c.via!)}'}';

  static String _subscriptionName(
    String? name,
    SubscriptionInfo info,
    String url,
  ) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return info.title ?? _hostOf(url);
  }

  static String _hostOf(String url) => Uri.tryParse(url)?.host ?? url;
}
