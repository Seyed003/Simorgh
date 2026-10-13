import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/storage/preferences.dart';
import '../../network/domain/network_identity.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../data/warp_client.dart';
import 'warp_service.dart';

/// Where the one-tap free config is in its work.
enum FreeConfigStep { network, account, checking, scanning }

sealed class FreeConfigOutcome {
  const FreeConfigOutcome(this.network);

  final NetworkIdentity network;
}

/// The free config is selected and works on [network].
class FreeConfigReady extends FreeConfigOutcome {
  const FreeConfigReady(super.network, this.profile, {required this.scanned});

  final Profile profile;

  /// A new endpoint was searched for (rather than the one remembered for
  /// this network).
  final bool scanned;
}

/// No WARP endpoint answered on [network].
class FreeConfigUnreachable extends FreeConfigOutcome {
  const FreeConfigUnreachable(super.network);
}

/// Names the free config after the network it was set up for, e.g.
/// "Free · Irancell".
typedef FreeConfigNamer = String Function(NetworkIdentity network);

final freeConfigServiceProvider = Provider<FreeConfigService>(
  FreeConfigService.new,
);

/// A free config in one tap: Cloudflare WARP, with the endpoint that is
/// fastest on the user's operator. Endpoints are remembered per network
/// (MCI, Irancell, Wi-Fi, ...), so switching SIM or Wi-Fi switches to the
/// endpoint found there, without scanning again.
class FreeConfigService {
  FreeConfigService(this._ref);

  final Ref _ref;

  static const _key = 'free_config';

  /// Scans of fresh endpoints before giving up.
  static const scanRounds = 2;

  Future<FreeConfigOutcome> setUp({
    required FreeConfigNamer name,
    void Function(FreeConfigStep step)? onStep,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    onStep?.call(FreeConfigStep.network);
    final network = await _network();
    final memory = _FreeConfigMemory.load(_prefsRead());
    final profiles = (await _ref.read(profilesProvider.future)).profiles;
    final ours = profiles
        .where((p) => p.id == memory.profileId && isWarp(p.config))
        .firstOrNull;

    // One WARP account for every network: only the endpoint differs.
    var base =
        ours?.config ??
        profiles.where((p) => isWarp(p.config)).firstOrNull?.config;
    final warp = _ref.read(warpServiceProvider);
    if (base == null) {
      onStep?.call(FreeConfigStep.account);
      base = (await warp.register()).config();
    }

    ProxyConfig? best;
    var scanned = false;
    final known = memory.endpoints[network.key];
    if (known != null) {
      onStep?.call(FreeConfigStep.checking);
      final candidate = withEndpoint(base, known.host, known.port);
      if (await warp.works(candidate)) best = candidate;
    }
    if (best == null) {
      onStep?.call(FreeConfigStep.scanning);
      best = await warp.bestEndpoint(base, rounds: scanRounds);
      scanned = true;
    }
    if (best == null) return FreeConfigUnreachable(network);

    final config = best.copyWith(name: name(network));
    final controller = _ref.read(profilesProvider.notifier);
    final Profile profile;
    if (ours == null) {
      profile = await controller.addAndSelect(config);
    } else {
      await controller.replaceConfig(ours.id, config);
      await controller.select(ours.id);
      profile = ours.copyWith(config: config);
    }
    memory
      ..profileId = profile.id
      ..endpoints[network.key] = (
        host: config.server,
        port: config.port,
        at: at,
      );
    await _save(memory);
    return FreeConfigReady(network, profile, scanned: scanned);
  }

  /// Before connecting: when the free config is selected and the network
  /// changed, switches it to the endpoint remembered for the new network
  /// (no scan; the button does that the first time on a network).
  Future<void> followNetwork({required FreeConfigNamer name}) async {
    final memory = _FreeConfigMemory.load(_prefsRead());
    if (memory.profileId == null) return;
    final state = await _ref.read(profilesProvider.future);
    final selected = state.selected;
    if (selected == null || selected.id != memory.profileId) return;
    final NetworkIdentity network;
    try {
      network = await _network();
    } on Object {
      return;
    }
    final known = memory.endpoints[network.key];
    if (known == null) return;
    final config = selected.config;
    if (config.server == known.host && config.port == known.port) return;
    await _ref
        .read(profilesProvider.notifier)
        .replaceConfig(
          selected.id,
          withEndpoint(
            config,
            known.host,
            known.port,
          ).copyWith(name: name(network)),
        );
  }

  /// The id of the free config, `null` before the first use.
  String? get profileId => _FreeConfigMemory.load(_prefsRead()).profileId;

  Future<NetworkIdentity> _network() async {
    try {
      return await _ref.read(systemBridgeProvider).network();
    } on Object {
      return const NetworkIdentity(kind: NetworkKind.other);
    }
  }

  String? _prefsRead() => _ref.read(sharedPreferencesProvider).getString(_key);

  Future<void> _save(_FreeConfigMemory memory) => _ref
      .read(sharedPreferencesProvider)
      .setString(_key, jsonEncode(memory.toJson()));
}

typedef _Endpoint = ({String host, int port, DateTime at});

class _FreeConfigMemory {
  _FreeConfigMemory(this.profileId, this.endpoints);

  String? profileId;

  /// By [NetworkIdentity.key].
  final Map<String, _Endpoint> endpoints;

  static _FreeConfigMemory load(String? raw) {
    final endpoints = <String, _Endpoint>{};
    String? profileId;
    try {
      final json = raw == null ? null : jsonDecode(raw);
      if (json is Map) {
        profileId = json['profile'] as String?;
        final map = json['endpoints'];
        if (map is Map) {
          for (final MapEntry(:key, :value) in map.entries) {
            if (key is! String || value is! Map) continue;
            final host = value['host'];
            final port = value['port'];
            final at = value['at'];
            if (host is String && port is int && at is int) {
              endpoints[key] = (
                host: host,
                port: port,
                at: DateTime.fromMillisecondsSinceEpoch(at),
              );
            }
          }
        }
      }
    } on Object {
      // Start over.
    }
    return _FreeConfigMemory(profileId, endpoints);
  }

  Map<String, Object?> toJson() => {
    'profile': profileId,
    'endpoints': {
      for (final MapEntry(:key, :value) in endpoints.entries)
        key: {
          'host': value.host,
          'port': value.port,
          'at': value.at.millisecondsSinceEpoch,
        },
    },
  };
}
