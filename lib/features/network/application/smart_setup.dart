import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/singbox/builder/config_builder.dart';
import '../../../core/singbox/builder/core_options.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../connection/application/vpn_controller.dart';
import '../../latency/application/latency_controller.dart';
import '../../latency/application/tester_lock.dart';
import '../../latency/data/latency_tester.dart';
import '../../latency/domain/latency_result.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../profiles/domain/profile.dart';
import '../../settings/application/core_options_controller.dart';
import '../domain/network_identity.dart';
import 'network_tuning.dart';

/// How one TLS fragment mode did on this network.
class ModeScore {
  const ModeScore({
    required this.mode,
    required this.ok,
    required this.total,
    this.medianMs,
  });

  final TlsFragmentMode mode;
  final int ok;
  final int total;
  final int? medianMs;
}

/// The mode that reached the most servers. Ties go to no fragmentation (it
/// costs nothing), then to the faster one. `null` when nothing answered.
TlsFragmentMode? pickBestMode(List<ModeScore> scores) {
  final best = scores.fold<int>(0, (m, s) => s.ok > m ? s.ok : m);
  if (best == 0) return null;
  final top = scores.where((s) => s.ok == best).toList();
  if (top.any((s) => s.mode == TlsFragmentMode.off)) return TlsFragmentMode.off;
  top.sort((a, b) => (a.medianMs ?? 1 << 30).compareTo(b.medianMs ?? 1 << 30));
  return top.first.mode;
}

/// A copy of [config] with exactly [mode] of fragmentation, whatever the
/// global setting.
ProxyConfig withFragment(ProxyConfig config, TlsFragmentMode mode) {
  final outbound = (jsonDecode(jsonEncode(config.outbound)) as Map)
      .cast<String, Object?>();
  if (outbound['type'] == 'xray') {
    outbound.remove('fragment');
    if (xrayFragment(mode) case final fragment?) {
      outbound['fragment'] = fragment;
    }
  } else if (outbound['tls'] case final Map<String, Object?> tls) {
    tls
      ..remove('fragment')
      ..remove('record_fragment');
    switch (mode) {
      case TlsFragmentMode.off:
        break;
      case TlsFragmentMode.record:
        tls['record_fragment'] = true;
      case TlsFragmentMode.tcp:
        tls['fragment'] = true;
    }
  }
  return ProxyConfig(
    protocol: config.protocol,
    name: config.name,
    server: config.server,
    port: config.port,
    outbound: outbound,
    via: config.via,
  );
}

enum SmartSetupPhase { idle, testing, done, noServers, nothingWorks }

class SmartSetupState {
  const SmartSetupState({
    this.phase = SmartSetupPhase.idle,
    this.network,
    this.scores = const [],
    this.chosen,
  });

  final SmartSetupPhase phase;
  final NetworkIdentity? network;
  final List<ModeScore> scores;
  final TlsFragmentMode? chosen;
}

/// Runs the same servers with each fragment mode on the test core and
/// keeps the one that gets through this network best.
typedef FragmentProbe = Future<Map<String, LatencyResult>> Function(
  Map<String, ProxyConfig> variants,
);

final fragmentProbeProvider = Provider<FragmentProbe>(
  (ref) => (variants) async {
    final tester = LatencyTester(
      platform: ref.read(vpnPlatformProvider),
      options: ref
          .read(coreOptionsProvider)
          .copyWith(tlsFragment: TlsFragmentMode.off),
    );
    return {
      for (final update in await tester.run(variants).toList())
        update.id: update.result,
    };
  },
);

final smartSetupProvider =
    NotifierProvider.autoDispose<SmartSetupController, SmartSetupState>(
      SmartSetupController.new,
    );

class SmartSetupController extends Notifier<SmartSetupState> {
  /// Servers tried per mode.
  static const sampleSize = 5;

  @override
  SmartSetupState build() => const SmartSetupState();

  Future<void> run() async {
    if (state.phase == SmartSetupPhase.testing) return;
    final network = await ref.read(systemBridgeProvider).network();
    final profiles = await ref.read(profilesProvider.future);
    final sample = _sample(profiles.profiles, profiles.selected);
    if (sample.isEmpty) {
      state = SmartSetupState(
        phase: SmartSetupPhase.noServers,
        network: network,
      );
      return;
    }
    state = SmartSetupState(phase: SmartSetupPhase.testing, network: network);

    final variants = {
      for (final mode in TlsFragmentMode.values)
        for (final p in sample)
          '${mode.name}|${p.id}': withFragment(p.config, mode),
    };
    // The test core is shared with latency and speed runs.
    await ref.read(latencyProvider.notifier).cancel();
    final results = await ref
        .read(testerLockProvider)
        .run(() => ref.read(fragmentProbeProvider)(variants));
    if (!ref.mounted) return;

    final scores = [
      for (final mode in TlsFragmentMode.values) _score(mode, sample, results),
    ];
    final best = pickBestMode(scores);
    if (best == null) {
      state = SmartSetupState(
        phase: SmartSetupPhase.nothingWorks,
        network: network,
        scores: scores,
      );
      return;
    }
    await ref
        .read(coreOptionsProvider.notifier)
        .update((o) => o.copyWith(tlsFragment: best));
    await ref
        .read(networkTuningProvider.notifier)
        .remember(network, best, measured: true);
    if (!ref.mounted) return;
    state = SmartSetupState(
      phase: SmartSetupPhase.done,
      network: network,
      scores: scores,
      chosen: best,
    );
  }

  /// TLS servers fragmentation can matter for: the selected one first, then
  /// the fastest recently tested.
  List<Profile> _sample(List<Profile> profiles, Profile? selected) {
    final latency = ref.read(latencyProvider).results;
    final candidates = profiles
        .where((p) => canFragment(p.config.outbound))
        .toList();
    int rank(Profile p) => latency[p.id]?.delay ?? 1 << 20;
    candidates.sort((a, b) => rank(a).compareTo(rank(b)));
    if (selected != null && candidates.remove(selected)) {
      candidates.insert(0, selected);
    }
    return candidates.take(sampleSize).toList();
  }

  ModeScore _score(
    TlsFragmentMode mode,
    List<Profile> sample,
    Map<String, LatencyResult> results,
  ) {
    final delays = [
      for (final p in sample) ?results['${mode.name}|${p.id}']?.delay,
    ]..sort();
    return ModeScore(
      mode: mode,
      ok: delays.length,
      total: sample.length,
      medianMs: delays.isEmpty ? null : delays[delays.length ~/ 2],
    );
  }
}
