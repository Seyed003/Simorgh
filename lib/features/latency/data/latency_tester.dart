import 'dart:async';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/singbox/builder/test_config_builder.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/utils/net_utils.dart';
import '../../connection/data/clash_api_client.dart';
import '../../connection/data/vpn_platform.dart';
import '../../connection/domain/vpn_state.dart';
import '../domain/latency_result.dart';

typedef LatencyUpdate = ({String id, LatencyResult result});

/// Measures the real delay of many servers at once: an HTTPS request to
/// [url] through each server, timed by a dedicated sing-box test core.
class LatencyTester {
  LatencyTester({
    required this.platform,
    required this.options,
    this.url = defaultUrl,
    this.timeout = const Duration(seconds: 5),
    this.concurrency = 8,
    ClashApiClient Function(ClashApiOptions)? clientFactory,
    DateTime Function()? clock,
  }) : _clientFactory = clientFactory ?? ClashApiClient.new,
       _clock = clock ?? DateTime.now;

  static const defaultUrl = 'https://www.gstatic.com/generate_204';

  final VpnPlatform platform;
  final CoreOptions options;
  final String url;
  final Duration timeout;
  final int concurrency;
  final ClashApiClient Function(ClashApiOptions) _clientFactory;
  final DateTime Function() _clock;

  /// Tests [proxies] (id -> config) and emits each result as it arrives.
  /// Cancelling the subscription stops the test core.
  Stream<LatencyUpdate> run(Map<String, ProxyConfig> proxies) async* {
    if (proxies.isEmpty) return;
    final api = ClashApiOptions(
      port: await findFreeLocalPort(),
      secret: randomHexSecret(),
    );
    final builder = TestConfigBuilder(options: options, clashApi: api);
    final pending = Map.of(proxies);

    // One invalid server must not sink the whole run: sing-box names the
    // outbound it rejects, so drop that one and validate again.
    TestConfig? config;
    while (pending.isNotEmpty) {
      final candidate = builder.build(pending);
      final error = await platform.checkConfig(candidate.encode());
      if (error == null) {
        config = candidate;
        break;
      }
      final blamed = candidate.idBlamedBy(error);
      if (blamed == null) {
        for (final id in pending.keys) {
          yield _failure(id, LatencyFailure.coreError);
        }
        return;
      }
      pending.remove(blamed);
      yield _failure(blamed, LatencyFailure.invalidConfig);
    }
    if (config == null) return;

    try {
      await platform.startTester(config.encode());
    } on VpnError {
      for (final id in pending.keys) {
        yield _failure(id, LatencyFailure.coreError);
      }
      return;
    }

    final client = _clientFactory(api);
    final results = StreamController<LatencyUpdate>();
    final queue = config.tagToId.entries.toList();
    var next = 0;
    var cancelled = false;

    Future<void> worker() async {
      while (!cancelled && next < queue.length) {
        final MapEntry(key: tag, value: id) = queue[next++];
        final delay = await client.delay(tag, url: url, timeout: timeout);
        if (cancelled) return;
        results.add((
          id: id,
          result: delay == null
              ? LatencyResult.failure(LatencyFailure.unreachable, _clock())
              : LatencyResult.success(delay, _clock()),
        ));
      }
    }

    unawaited(
      Future.wait([
        for (var i = 0; i < concurrency.clamp(1, queue.length); i++) worker(),
      ]).whenComplete(results.close),
    );

    try {
      yield* results.stream;
    } finally {
      cancelled = true;
      await platform.stopTester();
    }
  }

  LatencyUpdate _failure(String id, LatencyFailure failure) =>
      (id: id, result: LatencyResult.failure(failure, _clock()));
}
