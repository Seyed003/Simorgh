import 'dart:async';
import 'dart:convert';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/latency_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/speed_controller.dart';
import 'package:aghelan_ghiamat/features/latency/data/latency_tester.dart';
import 'package:aghelan_ghiamat/features/latency/data/speed_tester.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:aghelan_ghiamat/features/latency/domain/speed_result.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';
import 'latency_tester_test.dart' show stubApi;

/// Emits a scripted result per server, each after [gate] (if any) opens.
class _ScriptedSpeedTester extends SpeedTester {
  _ScriptedSpeedTester(
    FakeVpnPlatform platform,
    this.speeds, {
    this.gate,
    this.started,
  }) : super(platform: platform, options: const CoreOptions());

  final Map<String, int?> speeds;
  final Future<void>? gate;
  final void Function()? started;

  @override
  Stream<SpeedUpdate> run(Map<String, ProxyConfig> proxies) async* {
    started?.call();
    for (final id in proxies.keys) {
      if (gate != null) await gate;
      final speed = speeds[id];
      final at = DateTime(2026, 10, 12);
      yield (
        id: id,
        result: speed == null
            ? SpeedResult.failure(LatencyFailure.unreachable, at)
            : SpeedResult.success(speed, at),
      );
    }
  }
}

void main() {
  late FakeVpnPlatform platform;
  late List<String> ids;

  Future<ProviderContainer> create({
    Map<String, int?> Function(List<String> ids)? speeds,
    Future<void>? gate,
    void Function()? started,
    Map<String, Object> prefs = const {},
  }) async {
    platform = FakeVpnPlatform();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences(prefs),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
        speedTesterFactoryProvider.overrideWithValue(
          () => _ScriptedSpeedTester(
            platform,
            speeds?.call(ids) ?? const {},
            gate: gate,
            started: started,
          ),
        ),
        latencyTesterFactoryProvider.overrideWithValue(
          () => LatencyTester(
            platform: platform,
            options: const CoreOptions(),
            clientFactory: stubApi(const {'t0': 100, 't1': 200, 't2': 300}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profilesProvider.future);
    await container
        .read(profilesProvider.notifier)
        .importText('$vlessReality\n$trojanTls\n$hy2');
    ids = container
        .read(profilesProvider)
        .value!
        .profiles
        .map((p) => p.id)
        .toList();
    return container;
  }

  test('stores and persists results', () async {
    final c = await create(speeds: (ids) => {ids[0]: 2500000, ids[1]: null});
    await c.read(speedProvider.notifier).test(ids.take(2));

    final state = c.read(speedProvider);
    expect(state.running, isFalse);
    expect(state.current, isNull);
    expect(state.results[ids[0]]!.bytesPerSecond, 2500000);
    expect(state.results[ids[1]]!.failure, LatencyFailure.unreachable);
    expect(state.results.containsKey(ids[2]), isFalse);

    await Future<void>.delayed(Duration.zero);
    final saved = jsonDecode(
      c.read(sharedPreferencesProvider).getString('speed.results')!,
    ) as Map;
    expect(saved.keys, unorderedEquals(ids.take(2)));
  });

  test('tracks the server being measured and can be cancelled', () async {
    final gate = Completer<void>();
    final c = await create(
      speeds: (ids) => {ids[0]: 1000000},
      gate: gate.future,
    );
    final run = c.read(speedProvider.notifier).test(ids);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    var state = c.read(speedProvider);
    expect(state.running, isTrue);
    expect(state.current, ids[0]);
    expect(state.total, 3);

    final cancelling = c.read(speedProvider.notifier).cancel();
    // The UI stops at once, before the tester has wound down.
    state = c.read(speedProvider);
    expect(state.running, isFalse);
    // The (scripted) tester only notices at its next step.
    gate.complete();
    await cancelling.timeout(const Duration(seconds: 1));
    await run.timeout(const Duration(seconds: 1));
    expect(c.read(speedProvider).results, isEmpty);
  });

  test('a latency run waits for the speed run instead of clashing', () async {
    final gate = Completer<void>();
    final c = await create(
      speeds: (ids) => {ids[0]: 1000000},
      gate: gate.future,
    );
    final speed = c.read(speedProvider.notifier).test([ids[0]]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final latency = c.read(latencyProvider.notifier).testAll();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // The latency test core has not been started yet.
    expect(platform.testerConfigs, isEmpty);

    gate.complete();
    await speed;
    await latency;
    expect(platform.testerConfigs, hasLength(1));
    expect(c.read(latencyProvider).results, hasLength(3));
  });

  test('results survive a restart', () async {
    final c = await create(speeds: (ids) => {ids[0]: 1000000});
    await c.read(speedProvider.notifier).test([ids[0]]);
    await Future<void>.delayed(Duration.zero);
    final raw = c.read(sharedPreferencesProvider).getString('speed.results')!;

    final again = await create(prefs: {'speed.results': raw});
    // Ids are new after a fresh import, so look the saved one up directly.
    final saved = (jsonDecode(raw) as Map).keys.single as String;
    expect(again.read(speedProvider).results[saved]!.bytesPerSecond, 1000000);
  });
}
