import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/singbox/builder/core_options.dart';
import '../../../core/storage/preferences.dart';
import '../domain/network_identity.dart';

/// What works on one network.
class NetworkTuning {
  const NetworkTuning({
    required this.tlsFragment,
    required this.updatedAt,
    this.measured = false,
  });

  final TlsFragmentMode tlsFragment;
  final DateTime updatedAt;

  /// Found by the smart setup test (rather than picked by hand).
  final bool measured;

  Map<String, Object?> toJson() => {
    'tlsFragment': tlsFragment.name,
    'at': updatedAt.millisecondsSinceEpoch,
    'measured': measured,
  };

  static NetworkTuning? fromJson(Object? json) {
    if (json is! Map) return null;
    final mode = TlsFragmentMode.values.asNameMap()[json['tlsFragment']];
    final at = json['at'];
    if (mode == null || at is! int) return null;
    return NetworkTuning(
      tlsFragment: mode,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(at),
      measured: json['measured'] == true,
    );
  }
}

class NetworkTuningState {
  const NetworkTuningState({this.byNetwork = const {}, this.autoSwitch = true});

  /// By [NetworkIdentity.key].
  final Map<String, NetworkTuning> byNetwork;

  /// Apply the remembered settings when connecting on a known network.
  final bool autoSwitch;
}

/// The network the device is on now.
final currentNetworkProvider = FutureProvider.autoDispose<NetworkIdentity>(
  (ref) => ref.watch(systemBridgeProvider).network(),
);

final networkTuningProvider =
    NotifierProvider<NetworkTuningController, NetworkTuningState>(
      NetworkTuningController.new,
    );

class NetworkTuningController extends Notifier<NetworkTuningState> {
  static const _key = 'network.tuning';
  static const _autoKey = 'network.auto_switch';

  @override
  NetworkTuningState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final byNetwork = <String, NetworkTuning>{};
    try {
      final json = jsonDecode(prefs.getString(_key) ?? '{}');
      if (json is Map) {
        for (final MapEntry(:key, :value) in json.entries) {
          if (NetworkTuning.fromJson(value) case final tuning?) {
            byNetwork[key as String] = tuning;
          }
        }
      }
    } on FormatException {
      // Start over.
    }
    return NetworkTuningState(
      byNetwork: byNetwork,
      autoSwitch: prefs.getBool(_autoKey) ?? true,
    );
  }

  Future<void> remember(
    NetworkIdentity network,
    TlsFragmentMode mode, {
    bool measured = false,
    DateTime? now,
  }) async {
    final byNetwork = {
      ...state.byNetwork,
      network.key: NetworkTuning(
        tlsFragment: mode,
        updatedAt: now ?? DateTime.now(),
        measured: measured,
      ),
    };
    state = NetworkTuningState(
      byNetwork: byNetwork,
      autoSwitch: state.autoSwitch,
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode({
            for (final MapEntry(:key, :value) in byNetwork.entries)
              key: value.toJson(),
          }),
        );
  }

  Future<void> setAutoSwitch(bool on) async {
    state = NetworkTuningState(byNetwork: state.byNetwork, autoSwitch: on);
    await ref.read(sharedPreferencesProvider).setBool(_autoKey, on);
  }

  /// The remembered setting for [network] when automatic switching is on.
  NetworkTuning? forNetwork(NetworkIdentity network) =>
      state.autoSwitch ? state.byNetwork[network.key] : null;
}
