import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/singbox/builder/config_builder.dart';
import '../../../core/singbox/builder/core_options.dart';
import '../../../core/singbox/builder/test_config_builder.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/utils/net_utils.dart';
import '../../connection/data/clash_api_client.dart';
import '../../connection/data/vpn_platform.dart';
import '../domain/latency_result.dart';
import 'tester_core.dart';

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

  static const defaultUrl = SingBoxConfigBuilder.defaultTestUrl;

  final VpnPlatform platform;
  final CoreOptions options;
  final String url;
  final Duration timeout;
  final int concurrency;
  final ClashApiClient Function(ClashApiOptions) _clientFactory;
  final DateTime Function() _clock;

  /// Tests [proxies] (id -> config) and emits each result as it arrives.
  /// Cancelling the subscription stops the test core.
  Stream<LatencyUpdate> run(Map<String, ProxyConfig> all) async* {
    // Without its login a server cannot even be tried.
    final proxies = {
      for (final MapEntry(:key, :value) in all.entries)
        if (!value.needsLogin) key: value,
    };
    for (final id in all.keys) {
      if (!proxies.containsKey(id)) {
        yield _failure(id, LatencyFailure.invalidConfig);
      }
    }
    if (proxies.isEmpty) return;
    final api = ClashApiOptions(
      port: await findFreeLocalPort(),
      secret: randomHexSecret(),
    );
    final builder = TestConfigBuilder(options: options, clashApi: api);
    final (:config, :rejected) = await startTestCore(
      platform: platform,
      proxies: proxies,
      build: builder.build,
    );
    for (final MapEntry(key: id, value: reason) in rejected.entries) {
      yield _failure(id, switch (reason) {
        CoreRejection.invalidConfig => LatencyFailure.invalidConfig,
        CoreRejection.coreError => LatencyFailure.coreError,
      });
    }
    if (config == null) return;

    final client = _clientFactory(api);
    final results = StreamController<LatencyUpdate>();
    final queue = config.tagToId.entries.toList();
    var next = 0;
    var cancelled = false;

    Future<void> worker() async {
      while (!cancelled && next < queue.length) {
        final MapEntry(key: tag, value: id) = queue[next++];
        final delay = await _delay(
          client,
          tag,
          signsInFirst: proxies[id]!.protocol.connectsFirst,
          cancelled: () => cancelled,
        );
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

  /// OpenVPN and Cisco refuse traffic until they have signed in, so their
  /// test is repeated for up to [handshakeBudget].
  Future<int?> _delay(
    ClashApiClient client,
    String tag, {
    required bool signsInFirst,
    required bool Function() cancelled,
  }) async {
    final deadline = _clock().add(handshakeBudget);
    while (true) {
      final delay = await client.delay(tag, url: url, timeout: timeout);
      if (delay != null ||
          !signsInFirst ||
          cancelled() ||
          !_clock().isBefore(deadline)) {
        return delay;
      }
      await Future<void>.delayed(retryPause);
    }
  }

  /// Pause between attempts while a server signs in.
  @visibleForTesting
  static Duration retryPause = const Duration(seconds: 1);

  LatencyUpdate _failure(String id, LatencyFailure failure) =>
      (id: id, result: LatencyResult.failure(failure, _clock()));
}
