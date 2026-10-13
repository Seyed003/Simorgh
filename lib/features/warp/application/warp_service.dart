import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/proxy_config.dart';
import '../../connection/application/vpn_controller.dart';
import '../../latency/application/latency_controller.dart';
import '../../latency/application/tester_lock.dart';
import '../../latency/data/latency_tester.dart';
import '../../latency/domain/latency_result.dart';
import '../../settings/application/core_options_controller.dart';
import '../data/warp_client.dart';

/// Tests WireGuard variants of one config (id -> config) on the test core.
typedef EndpointProbe = Future<Map<String, LatencyResult>> Function(
  Map<String, ProxyConfig>,
);

final warpEndpointProbeProvider = Provider<EndpointProbe>(
  (ref) => (variants) async {
    final tester = LatencyTester(
      platform: ref.read(vpnPlatformProvider),
      options: ref.read(coreOptionsProvider),
    );
    return {
      for (final update in await tester.run(variants).toList())
        update.id: update.result,
    };
  },
);

final warpServiceProvider = Provider<WarpService>(WarpService.new);

class WarpService {
  WarpService(this._ref);

  final Ref _ref;

  /// Endpoints tried per scan.
  static const scanSize = 24;

  Future<WarpAccount> register() => _ref.read(warpClientProvider).register();

  /// The fastest of [scanSize] WARP endpoints for [config] on this
  /// network, as an updated config; `null` when none answered.
  Future<ProxyConfig?> bestEndpoint(ProxyConfig config) async {
    final variants = {
      for (final e in sampleWarpEndpoints(scanSize))
        '${e.host}:${e.port}': withEndpoint(config, e.host, e.port),
    };
    await _ref.read(latencyProvider.notifier).cancel();
    final results = await _ref
        .read(testerLockProvider)
        .run(() => _ref.read(warpEndpointProbeProvider)(variants));
    String? best;
    int? bestDelay;
    for (final MapEntry(key: id, value: result) in results.entries) {
      final delay = result.delay;
      if (delay != null && (bestDelay == null || delay < bestDelay)) {
        best = id;
        bestDelay = delay;
      }
    }
    return best == null ? null : variants[best];
  }
}
