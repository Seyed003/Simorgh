import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/data/clash_api_client.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';
import 'package:aghelan_ghiamat/features/latency/application/latency_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/speed_controller.dart';
import 'package:aghelan_ghiamat/features/latency/data/latency_tester.dart';
import 'package:aghelan_ghiamat/features/latency/data/speed_tester.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profiles_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';
import '../latency/latency_tester_test.dart' show stubApi;

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// A speed run that never finishes on its own.
class _EndlessSpeedTester extends SpeedTester {
  _EndlessSpeedTester(FakeVpnPlatform platform)
    : super(platform: platform, options: const CoreOptions());

  bool cancelled = false;

  @override
  Stream<SpeedUpdate> run(Map<String, ProxyConfig> proxies) =>
      StreamController<SpeedUpdate>(onCancel: () => cancelled = true).stream;
}

void main() {
  late FakeVpnPlatform platform;
  _EndlessSpeedTester? endlessSpeed;

  /// Three servers; [delays] are what the test core measures for them
  /// (`t0`..`t2` in import order).
  Future<ProviderContainer> create({
    Map<String, int?> delays = const {'t0': 300, 't1': null, 't2': 80},
    ClashApiClient Function(ClashApiOptions)? api,
    FakeVpnPlatform? fake,
    Map<String, Object> prefs = const {},
    bool auto = true,
    bool import = true,
  }) async {
    platform = fake ?? FakeVpnPlatform();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences(prefs),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
        latencyTesterFactoryProvider.overrideWithValue(
          () => LatencyTester(
            platform: platform,
            options: const CoreOptions(),
            clientFactory: api ?? stubApi(delays),
          ),
        ),
        speedTesterFactoryProvider.overrideWithValue(
          () => endlessSpeed = _EndlessSpeedTester(platform),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(vpnControllerProvider, (_, _) {});
    await container.read(profilesProvider.future);
    if (!import) return container;
    final profiles = container.read(profilesProvider.notifier);
    await profiles.importText('$vlessReality\n$trojanTls\n$hy2');
    if (auto) await profiles.select(ProfilesState.autoId);
    return container;
  }

  List<String> ids(ProviderContainer c) =>
      c.read(profilesProvider).value!.profiles.map((p) => p.id).toList();

  Map<String, Object?> lastConfig() =>
      jsonDecode(platform.requests.last.configJson) as Map<String, Object?>;

  test('without results it tests first, then connects fastest first', () async {
    final c = await create();
    final [reality, _, hy] = ids(c);
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();

    expect(platform.testerConfigs, hasLength(1));
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.connected);
    expect(state.profileId, ProfilesState.autoId);
    expect(state.isAuto, isTrue);
    // The failed server is left out; the fastest gets the first tag.
    expect(state.autoProfileIds, [hy, reality]);

    final group = (lastConfig()['outbounds']! as List).first as Map;
    expect(group['type'], 'urltest');
    expect(group['outbounds'], ['auto-0', 'auto-1']);
    expect(platform.requests.single.profileName, 'خودکار (سریع‌ترین سرور)');
  });

  test('fresh results are reused without another test', () async {
    final c = await create(delays: const {'t0': 300, 't1': 150, 't2': 80});
    await c.read(latencyProvider.notifier).testAll();
    expect(platform.testerConfigs, hasLength(1));

    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    expect(platform.testerConfigs, hasLength(1));
    expect(c.read(vpnControllerProvider).autoProfileIds, hasLength(3));
  });

  test('too few fresh working servers trigger a new test', () async {
    final c = await create();
    await c.read(latencyProvider.notifier).testAll();
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    // Only 2 of 3 answered, so the servers are measured again first.
    expect(platform.testerConfigs, hasLength(2));
    expect(c.read(vpnControllerProvider).status, VpnStatus.connected);
  });

  test('a running speed test does not hold up the search', () async {
    final c = await create();
    unawaited(c.read(speedProvider.notifier).test(ids(c)));
    await _settle();
    expect(c.read(speedProvider).running, isTrue);

    await c
        .read(vpnControllerProvider.notifier)
        .connect()
        .timeout(const Duration(seconds: 2));
    await _settle();
    expect(endlessSpeed!.cancelled, isTrue);
    expect(c.read(speedProvider).running, isFalse);
    expect(c.read(vpnControllerProvider).status, VpnStatus.connected);
  });

  test('no working server is an error and starts nothing', () async {
    final c = await create(delays: const {});
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.disconnected);
    expect(state.error!.code, VpnErrorCode.noWorkingServer);
    expect(platform.requests, isEmpty);
  });

  test('disconnecting during the search cancels it', () async {
    final gate = Completer<void>();
    final c = await create(
      api: (options) {
        final inner = stubApi(const {'t0': 100, 't1': 100, 't2': 100});
        return _GatedClient(inner(options), gate.future);
      },
    );
    final controller = c.read(vpnControllerProvider.notifier);
    final connecting = controller.connect();
    await _settle();
    expect(c.read(vpnControllerProvider).findingServer, isTrue);
    expect(c.read(vpnControllerProvider).status, VpnStatus.connecting);

    await controller.disconnect();
    gate.complete();
    await connecting;
    await _settle();
    expect(c.read(vpnControllerProvider).status, VpnStatus.disconnected);
    expect(c.read(latencyProvider).running, isFalse);
    expect(platform.requests, isEmpty);
    expect(platform.stopCalls, 0);
  });

  test('switching to auto while connected restarts in auto mode', () async {
    final c = await create(auto: false);
    final controller = c.read(vpnControllerProvider.notifier);
    await controller.connect();
    await _settle();
    expect(c.read(vpnControllerProvider).isAuto, isFalse);

    await c.read(profilesProvider.notifier).select(ProfilesState.autoId);
    await _settle();
    await _settle();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.connected);
    expect(state.isAuto, isTrue);
    expect(platform.requests, hasLength(2));
    expect(
      ((lastConfig()['outbounds']! as List).first as Map)['type'],
      'urltest',
    );
  });

  test('reattaches to a running auto session', () async {
    final c = await create(
      import: false,
      fake: FakeVpnPlatform(running: true),
      prefs: {
        'vpn.clash_api': jsonEncode({
          'port': 1234,
          'secret': 's',
          'profileId': 'auto',
          'auto': ['a', 'b'],
        }),
      },
    );
    await _settle();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.connected);
    expect(state.profileId, ProfilesState.autoId);
    expect(state.autoProfileIds, ['a', 'b']);
    expect(state.clashApi!.port, 1234);
  });

  test('active server comes from the core', () async {
    final c = await create();
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    final state = c.read(vpnControllerProvider);

    // Stand in for the core's Clash API on the port it was given.
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      state.clashApi!.port,
    );
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      expect(request.uri.path, '/proxies/proxy');
      request.response
        ..write(jsonEncode({'type': 'URLTest', 'now': 'auto-1'}))
        ..close();
    });

    final active = Completer<String>();
    c.listen(autoActiveProfileIdProvider, (_, next) {
      if (next.value case final id? when !active.isCompleted) {
        active.complete(id);
      }
    }, fireImmediately: true);
    expect(
      await active.future.timeout(const Duration(seconds: 5)),
      state.autoProfileIds[1],
    );
  });
}

/// Holds every delay request until [gate] completes.
class _GatedClient extends ClashApiClient {
  _GatedClient(this._inner, this._gate) : super(_inner.options);

  final ClashApiClient _inner;
  final Future<void> _gate;

  @override
  Future<int?> delay(
    String tag, {
    required String url,
    required Duration timeout,
  }) async {
    await _gate;
    return _inner.delay(tag, url: url, timeout: timeout);
  }
}
