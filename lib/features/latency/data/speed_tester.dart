import 'dart:async';
import 'dart:io';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/singbox/builder/test_config_builder.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/utils/net_utils.dart';
import '../../connection/data/vpn_platform.dart';
import '../domain/latency_result.dart';
import '../domain/speed_result.dart';
import 'tester_core.dart';

typedef SpeedUpdate = ({String id, SpeedResult result});

/// Measures download throughput through each server, one after another.
///
/// The test core exposes every server as its own local HTTP proxy; the app
/// downloads [url] through it for at most [duration] and reports the
/// average rate from the first response byte on (so the handshake does not
/// count against the server).
class SpeedTester {
  SpeedTester({
    required this.platform,
    required this.options,
    this.url = defaultUrl,
    this.duration = const Duration(seconds: 10),
    this.connectTimeout = const Duration(seconds: 10),
    this.stallTimeout = const Duration(seconds: 5),
    HttpClient Function()? httpClientFactory,
    DateTime Function()? clock,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _clock = clock ?? DateTime.now;

  /// Cloudflare's speed test endpoint; the download stops after [duration]
  /// anyway, so the size is only an upper bound.
  static const defaultUrl =
      'https://speed.cloudflare.com/__down?bytes=50000000';

  /// Less than this in total is treated as a failure, not a speed.
  static const minBytes = 32 * 1024;

  final VpnPlatform platform;
  final CoreOptions options;
  final String url;
  final Duration duration;
  final Duration connectTimeout;
  final Duration stallTimeout;
  final HttpClient Function() _httpClientFactory;
  final DateTime Function() _clock;

  /// Tests [proxies] (id -> config) in order and emits each result.
  /// Cancelling the subscription aborts the current download and stops the
  /// test core; the cancel future completes once the core is down.
  Stream<SpeedUpdate> run(Map<String, ProxyConfig> all) {
    // Without its login a server cannot even be tried.
    final proxies = {
      for (final MapEntry(:key, :value) in all.entries)
        if (!value.needsLogin) key: value,
    };
    HttpClient? active;
    var cancelled = false;
    late final StreamController<SpeedUpdate> results;

    Future<void> work() async {
      for (final id in all.keys) {
        if (!proxies.containsKey(id)) {
          results.add(_failure(id, LatencyFailure.invalidConfig));
        }
      }
      if (proxies.isEmpty) return;
      final ports = {
        for (final id in proxies.keys) id: await findFreeLocalPort(),
      };
      final builder = TestConfigBuilder(
        options: options,
        clashApi: ClashApiOptions(
          port: await findFreeLocalPort(),
          secret: randomHexSecret(),
        ),
      );
      // Other apps on the device must not borrow the servers meanwhile.
      final auth = (username: randomHexSecret(), password: randomHexSecret());
      final (:config, :rejected) = await startTestCore(
        platform: platform,
        proxies: proxies,
        build: (pending) =>
            builder.build(pending, localPorts: ports, localAuth: auth),
      );
      try {
        for (final MapEntry(key: id, value: reason) in rejected.entries) {
          results.add(
            _failure(id, switch (reason) {
              CoreRejection.invalidConfig => LatencyFailure.invalidConfig,
              CoreRejection.coreError => LatencyFailure.coreError,
            }),
          );
        }
        if (config == null) return;
        for (final id in config.tagToId.values) {
          if (cancelled) return;
          // OpenVPN and Cisco carry nothing until they have signed in.
          final deadline = proxies[id]!.protocol.connectsFirst
              ? _clock().add(handshakeBudget)
              : null;
          SpeedResult result;
          while (true) {
            final client = active = _httpClientFactory();
            // Hard stop per server, whatever the network does.
            result = await _measure(client, ports[id]!, auth).timeout(
              connectTimeout * 2 + duration + stallTimeout,
              onTimeout: () {
                client.close(force: true);
                return SpeedResult.failure(
                  LatencyFailure.unreachable,
                  _clock(),
                );
              },
            );
            if (result.ok ||
                cancelled ||
                deadline == null ||
                !_clock().isBefore(deadline)) {
              break;
            }
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          if (cancelled) return;
          results.add((id: id, result: result));
        }
      } finally {
        if (config != null) await platform.stopTester();
      }
    }

    Future<void>? working;
    var closing = false;
    results = StreamController<SpeedUpdate>(
      onListen: () {
        working = work().then<void>(
          (_) {},
          onError: (Object e) {
            if (!cancelled) results.addError(e);
          },
        );
        unawaited(
          working!.whenComplete(() {
            if (cancelled) return;
            closing = true;
            unawaited(results.close());
          }),
        );
      },
      onCancel: () {
        // Delivering the done event also lands here; nothing to wait for.
        if (closing) return null;
        cancelled = true;
        active?.close(force: true);
        // Completes once the test core is stopped, so whoever cancels can
        // safely start another one right after.
        return working;
      },
    );
    return results.stream;
  }

  Future<SpeedResult> _measure(
    HttpClient client,
    int port,
    ({String username, String password}) auth,
  ) async {
    client
      ..findProxy = ((_) =>
          'PROXY ${auth.username}:${auth.password}@127.0.0.1:$port')
      ..connectionTimeout = connectTimeout;
    final watch = Stopwatch();
    var bytes = 0;
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(connectTimeout);
      final response = await request.close().timeout(connectTimeout);
      if (response.statusCode != HttpStatus.ok) {
        return SpeedResult.failure(LatencyFailure.unreachable, _clock());
      }
      // Timers end the download, not the stream: waiting for a cancelled
      // response stream to wind down can take arbitrarily long.
      final finished = Completer<void>();
      void finish() {
        if (!finished.isCompleted) finished.complete();
      }

      Timer? stall;
      void rearmStall() {
        stall?.cancel();
        stall = Timer(stallTimeout, finish);
      }

      watch.start();
      final limit = Timer(duration, finish);
      final subscription = response.listen(
        (chunk) {
          bytes += chunk.length;
          rearmStall();
        },
        onError: (Object _) => finish(),
        onDone: finish,
        cancelOnError: true,
      );
      rearmStall();
      await finished.future;
      watch.stop();
      limit.cancel();
      stall?.cancel();
      unawaited(subscription.cancel());
    } on Object {
      // Connecting failed or timed out.
    } finally {
      watch.stop();
      client.close(force: true);
    }
    final micros = watch.elapsedMicroseconds;
    if (bytes < minBytes || micros <= 0) {
      return SpeedResult.failure(LatencyFailure.unreachable, _clock());
    }
    return SpeedResult.success(
      (bytes * Duration.microsecondsPerSecond / micros).round(),
      _clock(),
    );
  }

  SpeedUpdate _failure(String id, LatencyFailure failure) =>
      (id: id, result: SpeedResult.failure(failure, _clock()));
}
