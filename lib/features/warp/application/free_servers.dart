import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/subscription_url.dart';
import '../../profiles/application/profiles_controller.dart';

final freeServersServiceProvider = Provider<FreeServersService>(
  FreeServersService.new,
);

/// A free connection for someone who has not added a config yet: curated,
/// public V2Ray/Xray server lists that the app's auto-select then measures,
/// connecting to the fastest and failing over by itself.
///
/// The lists are fetched over the jsDelivr CDN, which keeps working on many
/// operators where `raw.githubusercontent.com` is blocked. They are public,
/// third-party servers — fast and free, but not anonymous or trusted — which
/// the UI makes clear before the first use.
class FreeServersService {
  FreeServersService(this._ref);

  final Ref _ref;

  /// Tried in order until one returns usable configs, so the most reliable,
  /// best-curated lists come first. Several more follow as fall-backs for
  /// when one is unreachable or a repo moves. All are small, already
  /// speed-curated lists (share links or a base64 blob of them) so the
  /// latency test can measure them on a phone without choking — not the
  /// giant thousands-of-config aggregators.
  static const sources = <String>[
    'https://cdn.jsdelivr.net/gh/0xRadikal/Free-v2ray-Configs@main/top100.txt',
    'https://cdn.jsdelivr.net/gh/mahdibland/V2RayAggregator@master/Eternity.txt',
    'https://cdn.jsdelivr.net/gh/mahdibland/ShadowsocksAggregator@master/Eternity.txt',
    'https://cdn.jsdelivr.net/gh/ripaojiedian/freenode@main/sub',
    'https://cdn.jsdelivr.net/gh/Pawdroid/Free-servers@main/sub',
  ];

  /// The sources as [addSubscription] stores them: it normalises the url it
  /// saves, so match against the normalised form, not the raw strings.
  static final _stored = {
    for (final s in sources) subscriptionUri(s)?.toString() ?? s.trim(),
  };

  bool _isOurs(String url) => _stored.contains(url);

  /// Whether the free-servers subscription has been imported before.
  Future<bool> exists() async {
    final state = await _ref.read(profilesProvider.future);
    return state.subscriptions.any((s) => _isOurs(s.url));
  }

  /// Imports the free-servers subscription, or refreshes it when it is
  /// already there, trying each source until one yields servers. Returns how
  /// many servers are available afterwards. Throws when no source can be
  /// reached and none were stored before.
  Future<int> ensure({required String name}) async {
    final controller = _ref.read(profilesProvider.notifier);
    final state = await _ref.read(profilesProvider.future);

    final mine = state.subscriptions.where((s) => _isOurs(s.url)).toList();
    if (mine.isNotEmpty) {
      final existing = mine.first;
      try {
        final outcome = await controller.updateSubscription(existing.id);
        return outcome.added;
      } on Object {
        // A refresh failed (offline, or the source is down right now):
        // keep the servers already stored so the user can still connect.
        return state.profilesOf(existing.id).length;
      }
    }

    Object? lastError;
    for (final url in sources) {
      try {
        final outcome = await controller.addSubscription(url, name: name);
        return outcome.added;
      } on Object catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('no free server source reachable');
  }
}
