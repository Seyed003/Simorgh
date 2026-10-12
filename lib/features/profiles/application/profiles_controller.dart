import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/singbox/proxy_config.dart';
import '../../../core/singbox/subscription_info.dart';
import '../../../core/singbox/subscription_parser.dart';
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

  /// Imports share links, base64 blobs or sing-box JSON from free text.
  /// A lone http(s) URL is treated as a subscription.
  Future<ImportOutcome> importText(String text) async {
    final trimmed = text.trim();
    if (_looksLikeSubscriptionUrl(trimmed)) {
      return addSubscription(trimmed);
    }
    final result = SubscriptionParser.parse(trimmed);
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
    return ImportOutcome(added: added.length, skipped: result.skipped.length);
  }

  Future<ImportOutcome> addSubscription(String url, {String? name}) async {
    final response = await ref.read(subscriptionClientProvider).fetch(url);
    final info = SubscriptionInfo.fromHeaders(response.headers);
    final result = SubscriptionParser.parse(response.body);
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
    final result = SubscriptionParser.parse(response.body);
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
      '${c.name}|${jsonEncode(c.outbound)}';

  static bool _looksLikeSubscriptionUrl(String text) {
    if (text.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
  }

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
