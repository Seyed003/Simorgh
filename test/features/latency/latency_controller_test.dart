import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/latency_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/profile_sort.dart';
import 'package:aghelan_ghiamat/features/latency/data/latency_tester.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';
import 'latency_tester_test.dart' show stubApi;

void main() {
  Future<ProviderContainer> create(
    Map<String, int?> delays, {
    Map<String, Object>? prefs,
  }) async {
    final platform = FakeVpnPlatform();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences(prefs ?? {}),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
        latencyTesterFactoryProvider.overrideWithValue(
          () => LatencyTester(
            platform: platform,
            options: const CoreOptions(),
            clientFactory: stubApi(delays),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profilesProvider.future);
    await container
        .read(profilesProvider.notifier)
        .importText('$vlessReality\n$trojanTls\n$hy2');
    return container;
  }

  test('testAll stores results and persists them', () async {
    final c = await create({'t0': 250, 't1': null, 't2': 90});
    final ids = c
        .read(profilesProvider)
        .value!
        .profiles
        .map((p) => p.id)
        .toList();
    await c.read(latencyProvider.notifier).testAll();

    final state = c.read(latencyProvider);
    expect(state.running, isFalse);
    expect(state.done, 3);
    expect(state.results[ids[0]]!.delay, 250);
    expect(state.results[ids[1]]!.failure, LatencyFailure.unreachable);
    expect(state.results[ids[2]]!.delay, 90);

    final saved = c
        .read(sharedPreferencesProvider)
        .getString('latency.results');
    expect(saved, contains(ids[2]));
  });

  test('results survive a restart', () async {
    final first = await create({'t0': 10, 't1': 20, 't2': 30});
    await first.read(latencyProvider.notifier).testAll();
    final saved = first
        .read(sharedPreferencesProvider)
        .getString('latency.results')!;
    final id = first.read(profilesProvider).value!.profiles.first.id;

    final second = await create({}, prefs: {'latency.results': saved});
    expect(second.read(latencyProvider).results[id]!.delay, 10);
  });

  test('sort by latency: fastest, then failed, then untested', () async {
    final c = await create({'t0': 250, 't1': null});
    final profiles = c.read(profilesProvider).value!.profiles;
    await c
        .read(latencyProvider.notifier)
        .test(profiles.take(2).map((p) => p.id));
    final results = c.read(latencyProvider).results;

    final sorted = sortProfiles(profiles, ProfileSort.latency, results);
    expect(sorted.map((p) => p.name), ['Reality 🇳🇱', 'Trojan', 'HY2']);
    expect(sortProfiles(profiles, ProfileSort.defaultOrder, results), profiles);

    await c.read(profileSortProvider.notifier).set(ProfileSort.latency);
    expect(
      c.read(sharedPreferencesProvider).getString('profiles.sort'),
      'latency',
    );
  });
}
