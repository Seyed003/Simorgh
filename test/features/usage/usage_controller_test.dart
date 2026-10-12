import 'dart:convert';

import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/data/clash_api_client.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/usage/application/usage_controller.dart';
import 'package:aghelan_ghiamat/features/usage/domain/usage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  final day1 = DateTime(2026, 10, 11, 23, 50);
  final day2 = DateTime(2026, 10, 12, 0, 10);

  Future<ProviderContainer> create([
    Map<String, Object> prefs = const {},
  ]) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences(prefs),
        ),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('counts only what moved since the last sample, per day', () async {
    final c = await create();
    final usage = c.read(usageProvider.notifier);
    await usage.record('s1', 100, 1000, now: day1);
    await usage.record('s1', 150, 1600, now: day1);
    await usage.record('s1', 150, 1600, now: day2); // nothing new
    await usage.record('s1', 200, 2600, now: day2);

    final state = c.read(usageProvider);
    expect(state.on(day1).up, 150);
    expect(state.on(day1).down, 1600);
    expect(state.on(day2).up, 50);
    expect(state.on(day2).down, 1000);
    expect(state.lastDays(7, day2).total, 150 + 1600 + 50 + 1000);
  });

  test('a new or restarted core counts in full', () async {
    final c = await create();
    final usage = c.read(usageProvider.notifier);
    await usage.record('s1', 100, 1000, now: day1);
    await usage.record('s2', 10, 20, now: day1); // new session
    await usage.record('s2', 5, 5, now: day1); // core restarted
    expect(c.read(usageProvider).on(day1).total, 1100 + 30 + 10);
  });

  test('persists, survives a restart and resets', () async {
    final c = await create();
    await c.read(usageProvider.notifier).record('s1', 7, 9, now: day1);
    final prefs = c.read(sharedPreferencesProvider);
    final again = await create({
      'usage.daily': prefs.getString('usage.daily')!,
      'usage.session': prefs.getString('usage.session')!,
    });
    expect(again.read(usageProvider).on(day1).total, 16);
    // The same core session continues from its last totals.
    await again.read(usageProvider.notifier).record('s1', 10, 10, now: day1);
    expect(again.read(usageProvider).on(day1).total, 20);

    await again.read(usageProvider.notifier).reset();
    expect(again.read(usageProvider).days, isEmpty);
  });

  test('old days are dropped', () async {
    final c = await create();
    final usage = c.read(usageProvider.notifier);
    await usage.record('s1', 1, 1, now: DateTime(2026, 1, 1));
    await usage.record('s1', 2, 2, now: DateTime(2026, 10, 12));
    expect(c.read(usageProvider).days.keys, [DateTime(2026, 10, 12)]);
  });

  test('samples the core, and once more on disconnect', () async {
    final c = await create();
    var totals = (up: 300, down: 4000);
    c.read(usageProvider.notifier).clientFactory = (api) => ClashApiClient(
      api,
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/connections');
        return http.Response(
          jsonEncode({
            'uploadTotal': totals.up,
            'downloadTotal': totals.down,
            'connections': <Object>[],
          }),
          200,
        );
      }),
    );
    c.listen(vpnControllerProvider, (_, _) {});
    await c.read(profilesProvider.future);
    await c.read(profilesProvider.notifier).importText(trojanBare);
    await c.read(vpnControllerProvider.notifier).connect();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await c
        .read(usageProvider.notifier)
        .sample(c.read(vpnControllerProvider).clashApi!);
    expect(c.read(usageProvider).on(DateTime.now()).total, 4300);

    totals = (up: 500, down: 9000);
    await c.read(vpnControllerProvider.notifier).disconnect();
    expect(c.read(usageProvider).on(DateTime.now()).up, 500);
    expect(c.read(usageProvider).on(DateTime.now()).down, 9000);
  });

  test('sums the right window', () {
    final state = UsageState(
      days: {
        DateTime(2026, 10, 12): const DayUsage(up: 1, down: 2),
        DateTime(2026, 10, 6): const DayUsage(up: 10, down: 20),
        DateTime(2026, 10, 5): const DayUsage(up: 100, down: 200),
      },
    );
    expect(state.lastDays(7, DateTime(2026, 10, 12, 18)).total, 33);
    expect(state.lastDays(30, DateTime(2026, 10, 12)).total, 333);
  });
}
