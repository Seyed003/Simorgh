import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/config_builder.dart';
import '../../../core/singbox/builder/core_options.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/net_utils.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../../settings/application/core_options_controller.dart';
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

class VpnController extends Notifier<VpnState> {
  static const _clashKey = 'vpn.clash_api';

  StreamSubscription<VpnPlatformEvent>? _events;
  bool _restartPending = false;

  VpnPlatform get _platform => ref.read(vpnPlatformProvider);

  @override
  VpnState build() {
    final platform = ref.watch(vpnPlatformProvider);
    _events = platform.events.listen(_onEvent);
    ref.onDispose(() => _events?.cancel());

    // Switching servers while connected restarts the core on the new one.
    ref.listen<Profile?>(selectedProfileProvider, (previous, next) {
      if (next != null && state.isConnected && next.id != state.profileId) {
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
    final profile = ref.read(selectedProfileProvider);
    if (profile == null) {
      state = state.copyWith(
        error: () => const VpnError(VpnErrorCode.invalidConfig),
      );
      return;
    }
    final platform = _platform;
    final clashApi = ClashApiOptions(
      port: await findFreeLocalPort(),
      secret: randomHexSecret(),
    );
    final builder = SingBoxConfigBuilder(
      options: ref.read(coreOptionsProvider),
      platform: platform.corePlatform,
      clashApi: clashApi,
    );

    final String configJson;
    try {
      configJson = builder.buildJson(profile.config);
    } on Exception catch (e) {
      state = state.copyWith(
        error: () => VpnError(VpnErrorCode.invalidConfig, e.toString()),
      );
      return;
    }

    state = VpnState(
      status: VpnStatus.connecting,
      profileId: profile.id,
      clashApi: clashApi,
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _clashKey,
          jsonEncode({'port': clashApi.port, 'secret': clashApi.secret}),
        );
    try {
      await platform.start(
        VpnStartRequest(configJson: configJson, profileName: profile.name),
      );
    } on VpnError catch (e) {
      state = VpnState(error: e);
    } on Exception catch (e) {
      state = VpnState(error: VpnError(VpnErrorCode.unknown, e.toString()));
    }
  }

  Future<void> disconnect() async {
    if (state.status == VpnStatus.disconnected) return;
    state = state.copyWith(status: VpnStatus.disconnecting);
    try {
      await _platform.stop();
    } on Exception catch (e) {
      state = VpnState(error: VpnError(VpnErrorCode.unknown, e.toString()));
    }
  }

  /// Reconnects with the currently selected profile.
  Future<void> restart() async {
    if (state.status == VpnStatus.disconnected) return connect();
    _restartPending = true;
    await disconnect();
  }

  void clearError() => state = state.copyWith(error: () => null);

  void _onEvent(VpnPlatformEvent event) {
    switch (event) {
      case VpnStarted():
        state = state.copyWith(
          status: VpnStatus.connected,
          connectedSince: () => DateTime.now(),
          error: () => null,
        );
      case VpnStopped(:final error):
        state = VpnState(error: error);
        if (_restartPending) {
          _restartPending = false;
          if (error == null) unawaited(connect());
        }
      case VpnLogLine():
        break;
    }
  }

  /// Android keeps the VpnService alive when the UI is closed; reattach to
  /// it so the home screen reflects reality after a relaunch.
  Future<void> _restoreRunningService(VpnPlatform platform) async {
    if (!await platform.isRunning()) return;
    final raw = ref.read(sharedPreferencesProvider).getString(_clashKey);
    ClashApiOptions? clashApi;
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, Object?>;
      clashApi = ClashApiOptions(
        port: json['port']! as int,
        secret: json['secret']! as String,
      );
    }
    if (state.status != VpnStatus.disconnected) return;
    state = VpnState(
      status: VpnStatus.connected,
      connectedSince: DateTime.now(),
      profileId: ref.read(selectedProfileProvider)?.id,
      clashApi: clashApi,
    );
  }
}
