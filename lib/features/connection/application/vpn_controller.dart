import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/config_builder.dart';
import '../../../core/singbox/builder/core_options.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/net_utils.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../latency/application/auto_candidates.dart';
import '../../latency/application/latency_controller.dart';
import '../../latency/application/speed_controller.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profiles_state.dart';
import '../../settings/application/core_options_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../usage/application/usage_controller.dart';
import '../data/clash_api_client.dart';
import '../data/platform_factory.dart';
import '../data/vpn_platform.dart';
import '../domain/traffic.dart';
import '../domain/vpn_state.dart';

final vpnPlatformProvider = Provider<VpnPlatform>((ref) => createVpnPlatform());

final vpnControllerProvider = NotifierProvider<VpnController, VpnState>(
  VpnController.new,
);

/// Live traffic of the running core, reset on every connection.
final trafficProvider = StreamProvider.autoDispose<TrafficStats>((ref) async* {
  final api = ref.watch(
    vpnControllerProvider.select((s) => s.isConnected ? s.clashApi : null),
  );
  var stats = TrafficStats.zero;
  yield stats;
  if (api == null) return;
  final client = ClashApiClient(api);
  while (ref.mounted) {
    try {
      await for (final sample in client.traffic()) {
        stats = stats.add(sample.up, sample.down);
        yield stats;
      }
    } on Object {
      // The core may still be starting or briefly unavailable; retry.
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

/// In auto mode, the profile the core currently routes through (`null`
/// until the core's first test picks one).
final autoActiveProfileIdProvider = StreamProvider.autoDispose<String?>((
  ref,
) async* {
  final session = ref.watch(
    vpnControllerProvider.select(
      (s) => s.isConnected && s.isAuto && s.clashApi != null
          ? (api: s.clashApi!, ids: s.autoProfileIds)
          : null,
    ),
  );
  if (session == null) {
    yield null;
    return;
  }
  final client = ClashApiClient(session.api);
  while (ref.mounted) {
    final tag = await client.proxyNow(ConfigTags.proxy);
    final index = tag == null ? null : SingBoxConfigBuilder.autoIndexOf(tag);
    yield index != null && index < session.ids.length
        ? session.ids[index]
        : null;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

class VpnController extends Notifier<VpnState> {
  /// Clash API endpoint and profile of the running core, so a relaunched UI
  /// can reattach to a VpnService that kept running.
  static const _sessionKey = 'vpn.clash_api';

  StreamSubscription<VpnPlatformEvent>? _events;
  bool _restartPending = false;

  /// Bumped by every connect and disconnect, so a connect that is still
  /// searching for a server notices it was cancelled.
  int _attempt = 0;

  VpnPlatform get _platform => ref.read(vpnPlatformProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(settingsProvider).language.locale);

  @override
  VpnState build() {
    final platform = ref.watch(vpnPlatformProvider);
    _events = platform.events.listen(_onEvent);
    ref.onDispose(() => _events?.cancel());

    // Switching servers (or to auto mode) while connected restarts the core.
    ref.listen<String?>(profilesProvider.select((s) => s.value?.selectedId), (
      previous,
      next,
    ) {
      if (next != null && state.isConnected && next != state.profileId) {
        unawaited(restart());
      }
    });

    // New core options take effect immediately on a live connection.
    ref.listen<CoreOptions>(coreOptionsProvider, (previous, next) {
      if (previous != next && state.isConnected) unawaited(restart());
    });

    unawaited(_restoreRunningService(platform));
    return const VpnState();
  }

  Future<void> toggle() async {
    switch (state.status) {
      case VpnStatus.disconnected:
        await connect();
      case VpnStatus.connected:
      case VpnStatus.connecting:
        await disconnect();
      case VpnStatus.disconnecting:
        break;
    }
  }

  Future<void> connect() async {
    final attempt = ++_attempt;
    final ProfilesState profiles;
    try {
      profiles = await ref.read(profilesProvider.future);
    } on Object catch (e) {
      state = VpnState(error: VpnError(VpnErrorCode.unknown, e.toString()));
      return;
    }
    if (attempt != _attempt) return;
    if (profiles.isAuto) return _connectAuto(attempt);

    final profile = profiles.selected;
    if (profile == null) {
      state = state.copyWith(
        error: () => const VpnError(VpnErrorCode.invalidConfig),
      );
      return;
    }
    await _start(
      attempt,
      profileId: profile.id,
      profileName: profile.name,
      build: (builder) => builder.buildJson(profile.config),
    );
  }

  /// Auto mode: the fastest recently tested servers go into a `urltest`
  /// group; the core then keeps using the best one and fails over by itself.
  /// Without fresh results the servers are measured first.
  Future<void> _connectAuto(int attempt) async {
    state = const VpnState(
      status: VpnStatus.connecting,
      profileId: ProfilesState.autoId,
      findingServer: true,
    );
    var (candidates, total) = await _autoCandidates();
    if (candidates.length < min(autoMinCandidates, total)) {
      // A speed test would hold the test core for minutes.
      await ref.read(speedProvider.notifier).cancel();
      await ref.read(latencyProvider.notifier).testAll();
      if (attempt != _attempt) return;
      (candidates, total) = await _autoCandidates();
    }
    if (attempt != _attempt) return;
    if (candidates.isEmpty) {
      state = const VpnState(error: VpnError(VpnErrorCode.noWorkingServer));
      return;
    }
    await _start(
      attempt,
      profileId: ProfilesState.autoId,
      profileName: _l10n.autoSelect,
      autoProfileIds: [for (final p in candidates) p.id],
      build: (builder) =>
          builder.buildAutoJson([for (final p in candidates) p.config]),
    );
  }

  Future<(List<Profile>, int)> _autoCandidates() async {
    final profiles = (await ref.read(profilesProvider.future)).profiles;
    final candidates = pickAutoCandidates(
      profiles,
      ref.read(latencyProvider).results,
      now: DateTime.now(),
    );
    return (candidates, profiles.length);
  }

  Future<void> _start(
    int attempt, {
    required String profileId,
    required String profileName,
    required String Function(SingBoxConfigBuilder builder) build,
    List<String> autoProfileIds = const [],
  }) async {
    final platform = _platform;
    final clashApi = ClashApiOptions(
      port: await findFreeLocalPort(),
      secret: randomHexSecret(),
    );
    if (attempt != _attempt) return;
    final builder = SingBoxConfigBuilder(
      options: ref.read(coreOptionsProvider),
      platform: platform.corePlatform,
      clashApi: clashApi,
    );

    final String configJson;
    try {
      configJson = build(builder);
    } on Exception catch (e) {
      state = VpnState(
        error: VpnError(VpnErrorCode.invalidConfig, e.toString()),
      );
      return;
    }

    state = VpnState(
      status: VpnStatus.connecting,
      profileId: profileId,
      clashApi: clashApi,
      autoProfileIds: autoProfileIds,
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _sessionKey,
          jsonEncode({
            'port': clashApi.port,
            'secret': clashApi.secret,
            'profileId': profileId,
            'auto': autoProfileIds,
          }),
        );
    if (attempt != _attempt) return;
    try {
      await platform.start(
        VpnStartRequest(configJson: configJson, profileName: profileName),
      );
    } on VpnError catch (e) {
      state = VpnState(error: e);
    } on Exception catch (e) {
      state = VpnState(error: VpnError(VpnErrorCode.unknown, e.toString()));
    }
  }

  Future<void> disconnect() async {
    if (state.status == VpnStatus.disconnected) return;
    _attempt++;
    if (state.findingServer) {
      // The core was never started: just abandon the search.
      state = const VpnState();
      await ref.read(latencyProvider.notifier).cancel();
      _connectIfRestartPending(null);
      return;
    }
    // Count the last seconds of traffic before the core goes away.
    final api = state.clashApi;
    if (api != null && state.isConnected) {
      await ref
          .read(usageProvider.notifier)
          .sample(api)
          .timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    state = state.copyWith(status: VpnStatus.disconnecting);
    try {
      await _platform.stop();
    } on Exception catch (e) {
      state = VpnState(error: VpnError(VpnErrorCode.unknown, e.toString()));
    }
  }

  /// Reconnects with the current selection.
  Future<void> restart() async {
    if (state.status == VpnStatus.disconnected) return connect();
    _restartPending = true;
    await disconnect();
  }

  void clearError() => state = state.copyWith(error: () => null);

  void _onEvent(VpnPlatformEvent event) {
    switch (event) {
      case VpnStarted():
        // Started outside the app (quick settings tile, widget): pick up
        // the session the app saved when it wrote that config.
        final session = state.clashApi == null ? _loadSession() : null;
        state = state.copyWith(
          status: VpnStatus.connected,
          connectedSince: () => DateTime.now(),
          error: () => null,
          clashApi: session == null ? null : () => session.clashApi,
          profileId: session == null ? null : () => session.profileId,
          autoProfileIds: session?.autoProfileIds,
        );
      case VpnStopped(:final error):
        // A stale stop from the platform must not end a server search.
        if (state.findingServer) return;
        final dropped = error != null && state.isConnected && !_restartPending;
        state = VpnState(error: error);
        _connectIfRestartPending(error);
        if (dropped) unawaited(_reconnectAfterDrop());
      case VpnLogLine():
        break;
    }
  }

  /// When the core dies under a live connection, apps would carry on
  /// without the tunnel: reconnect once, unless that just happened.
  Future<void> _reconnectAfterDrop() async {
    final now = DateTime.now();
    final last = _lastDropReconnect;
    if (last != null && now.difference(last) < reconnectCooldown) return;
    _lastDropReconnect = now;
    final attempt = _attempt;
    await Future<void>.delayed(reconnectDelay);
    if (!ref.mounted ||
        attempt != _attempt ||
        state.status != VpnStatus.disconnected) {
      return;
    }
    await connect();
  }

  @visibleForTesting
  static Duration reconnectDelay = const Duration(seconds: 2);
  static const reconnectCooldown = Duration(minutes: 2);
  DateTime? _lastDropReconnect;

  void _connectIfRestartPending(VpnError? error) {
    if (!_restartPending) return;
    _restartPending = false;
    if (error == null) unawaited(connect());
  }

  /// Android keeps the VpnService alive when the UI is closed; reattach to
  /// it so the home screen reflects reality after a relaunch.
  Future<void> _restoreRunningService(VpnPlatform platform) async {
    if (!await platform.isRunning()) return;
    final session = _loadSession();
    var profileId = session?.profileId;
    if (profileId == null) {
      try {
        profileId = (await ref.read(profilesProvider.future)).selectedId;
      } on Object {
        // Shown as connected without a known profile.
      }
    }
    if (state.status != VpnStatus.disconnected) return;
    state = VpnState(
      status: VpnStatus.connected,
      connectedSince: DateTime.now(),
      profileId: profileId,
      clashApi: session?.clashApi,
      autoProfileIds: session?.autoProfileIds ?? const [],
    );
  }

  ({ClashApiOptions clashApi, String? profileId, List<String> autoProfileIds})?
  _loadSession() {
    final raw = ref.read(sharedPreferencesProvider).getString(_sessionKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return (
        clashApi: ClashApiOptions(
          port: json['port']! as int,
          secret: json['secret']! as String,
        ),
        profileId: json['profileId'] as String?,
        autoProfileIds: [
          ...((json['auto'] as List?) ?? const []).whereType<String>(),
        ],
      );
    } on Object {
      return null;
    }
  }
}
