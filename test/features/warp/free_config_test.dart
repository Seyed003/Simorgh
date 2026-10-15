import 'dart:convert';

import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/platform/system_bridge.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:aghelan_ghiamat/features/network/application/internet_reach.dart';
import 'package:aghelan_ghiamat/features/network/domain/network_identity.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/data/subscription_client.dart';
import 'package:aghelan_ghiamat/features/warp/application/free_config.dart';
import 'package:aghelan_ghiamat/features/warp/application/warp_service.dart';
import 'package:aghelan_ghiamat/features/warp/data/warp_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';
import 'warp_test.dart' show warpAnswer;

class _Network extends SystemBridge {
  NetworkIdentity current = _irancell;

  @override
  Future<NetworkIdentity> network() async => current;
}

const _irancell = NetworkIdentity(kind: NetworkKind.cellular, mccMnc: '43235');
const _mci = NetworkIdentity(kind: NetworkKind.cellular, mccMnc: '43211');

/// Filtering differs per operator: Irancell lets WARP through only on
/// its default port 2408 (always among the tried endpoints), MCI on every
/// port but that one.
bool _defaultRule(NetworkIdentity network, int port) =>
    network.mccMnc == '43235' ? port == 2408 : port != 2408;

void main() {
  late _Network bridge;
  late int registrations;
  late int probes;

  /// Which endpoints answer; by default each operator's one port.
  late bool Function(String host, int port) answers;

  Future<ProviderContainer> create({
    Map<String, Object> prefs = const {},
  }) async {
    bridge = _Network();
    registrations = 0;
    probes = 0;
    answers = (_, port) => _defaultRule(bridge.current, port);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences(prefs),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
        // The free-servers lists are out of reach here, so the free button
        // falls back to WARP — the deterministic path these tests exercise.
        httpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('', 404)),
        ),
        reachProbeProvider.overrideWithValue(const FakeReachProbe()),
        trafficProvider.overrideWith((ref) => Stream.value(TrafficStats.zero)),
        systemBridgeProvider.overrideWithValue(bridge),
        warpClientProvider.overrideWithValue(
          WarpClient(
            MockClient((_) async {
              registrations++;
              return http.Response(warpAnswer(), 200);
            }),
          ),
        ),
        warpEndpointProbeProvider.overrideWithValue((variants) async {
          probes++;
          return {
            for (final MapEntry(:key, :value) in variants.entries)
              key: answers(value.server, value.port)
                  ? LatencyResult.success(
                      // The fastest route: the lowest last octet.
                      100 + int.parse(value.server.split('.').last),
                      DateTime(2026),
                    )
                  : LatencyResult.failure(
                      LatencyFailure.unreachable,
                      DateTime(2026),
                    ),
          };
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profilesProvider.future);
    return container;
  }

  String name(NetworkIdentity n) => 'Free · ${n.mccMnc}';

  test('one tap: account, fastest route on this operator, selected', () async {
    final c = await create();
    final service = c.read(freeConfigServiceProvider);
    final steps = <FreeConfigStep>[];
    final outcome = await service.setUp(name: name, onStep: steps.add);

    expect(outcome, isA<FreeConfigReady>());
    final ready = outcome as FreeConfigReady;
    expect(ready.scanned, isTrue);
    expect(ready.profile.config.port, 2408);
    expect(ready.profile.name, 'Free · 43235');
    expect(registrations, 1);
    expect(steps, [
      FreeConfigStep.network,
      FreeConfigStep.account,
      FreeConfigStep.scanning,
    ]);
    final state = c.read(profilesProvider).value!;
    expect(state.selectedId, ready.profile.id);
    expect(state.profiles, hasLength(1));
    expect(isWarp(state.profiles.single.config), isTrue);
  });

  test('the same network again: the remembered route, no scan', () async {
    final c = await create();
    final service = c.read(freeConfigServiceProvider);
    final first = await service.setUp(name: name) as FreeConfigReady;
    probes = 0;
    final again = await service.setUp(name: name) as FreeConfigReady;
    expect(again.scanned, isFalse);
    expect(probes, 1, reason: 'one quick check of the remembered route');
    expect(again.profile.id, first.profile.id);
    expect(registrations, 1, reason: 'the WARP account is kept');
    expect(c.read(profilesProvider).value!.profiles, hasLength(1));
  });

  test(
    'another operator gets its own route, and switching back follows',
    () async {
      final c = await create();
      final service = c.read(freeConfigServiceProvider);
      await service.setUp(name: name);

      bridge.current = _mci;
      final mci = await service.setUp(name: name) as FreeConfigReady;
      expect(mci.profile.config.port, isNot(2408));
      expect(mci.profile.name, 'Free · 43211');
      expect(registrations, 1);
      expect(c.read(profilesProvider).value!.profiles, hasLength(1));

      // Back on Irancell, connecting switches to its route without a scan.
      bridge.current = _irancell;
      probes = 0;
      await c.read(vpnControllerProvider.notifier).connect();
      final profile = c.read(profilesProvider).value!.selected!;
      expect(profile.config.port, 2408);
      expect(profile.name, startsWith('رایگان'));
      expect(probes, 0);
      final platform = c.read(vpnPlatformProvider) as FakeVpnPlatform;
      final config = jsonDecode(platform.requests.last.configJson) as Map;
      final endpoint = (config['endpoints']! as List).single as Map;
      expect(((endpoint['peers']! as List).single as Map)['port'], 2408);
    },
  );

  test('a remembered route that stopped working is replaced', () async {
    final c = await create();
    final service = c.read(freeConfigServiceProvider);
    answers = (_, _) => true;
    final first = await service.setUp(name: name) as FreeConfigReady;
    final blocked = first.profile.config.server;
    answers = (host, _) => host != blocked;
    final second = await service.setUp(name: name) as FreeConfigReady;
    expect(second.scanned, isTrue);
    expect(second.profile.config.server, isNot(blocked));
    expect(second.profile.id, first.profile.id);
  });

  test('nothing answers: says so and changes nothing', () async {
    final c = await create();
    answers = (_, _) => false;
    final outcome = await c.read(freeConfigServiceProvider).setUp(name: name);
    expect(outcome, isA<FreeConfigUnreachable>());
    expect(outcome.network, _irancell);
    expect(c.read(profilesProvider).value!.profiles, isEmpty);
  });

  test('other configs and an existing WARP account are reused', () async {
    final c = await create();
    await c.read(profilesProvider.notifier).importText(vlessWs);
    final account = await c.read(warpServiceProvider).register();
    await c.read(profilesProvider.notifier).importText(account.link());
    registrations = 0;

    final ready =
        await c.read(freeConfigServiceProvider).setUp(name: name)
            as FreeConfigReady;
    expect(registrations, 0);
    final profiles = c.read(profilesProvider).value!.profiles;
    expect(profiles, hasLength(3));
    expect(c.read(profilesProvider).value!.selectedId, ready.profile.id);
  });

  testWidgets('the home button discloses, falls back to WARP and connects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ProviderContainer c;
    await tester.runAsync(() async {
      c = await create(prefs: {'settings.language': 'en'});
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const AghelanApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Free connection'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    // First use shows the public-servers disclosure.
    expect(find.text('Free servers'), findsOneWidget);
    await tester.tap(find.text('Find and connect'));
    // The curated lists 404 here, so it falls back to WARP without a second
    // prompt and connects. (The free-servers happy path is unit-tested in
    // free_servers_test.dart; here we check the button's wiring.) Two progress
    // dialogs and a real free local port are involved, so pump single frames —
    // their spinners would stall pumpAndSettle — while the async work runs,
    // until the core is handed its config.
    final platform = c.read(vpnPlatformProvider) as FakeVpnPlatform;
    for (var i = 0; i < 100 && platform.requests.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(platform.requests, hasLength(1));
    expect(c.read(profilesProvider).value!.selected!.name, 'Free · Irancell');
  });

  testWidgets('the button fits a small phone in Persian', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ProviderContainer c;
    await tester.runAsync(() async {
      c = await create(prefs: {'settings.language': 'fa'});
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const AghelanApp()),
    );
    await tester.pumpAndSettle();
    // A layout overflow would fail the test on its own.
    expect(find.text('اتصال رایگان'), findsOneWidget);
  });
}
