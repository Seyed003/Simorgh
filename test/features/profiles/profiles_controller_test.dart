import 'dart:convert';

import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/data/subscription_client.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profiles_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';

import '../../core/singbox/fixtures.dart';
import '../../core/singbox/openvpn_fixtures.dart';
import '../../helpers.dart';

void main() {
  late MemoryProfileStore store;
  late Map<String, String> served;
  late List<http.Request> requests;

  Future<ProviderContainer> create() async {
    final prefs = await mockPreferences();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(store),
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            requests.add(request);
            final body = served[request.url.toString()];
            if (body == null) return http.Response('not found', 404);
            return http.Response(
              body,
              200,
              headers: {
                'subscription-userinfo':
                    'upload=10; download=20; total=100; expire=0',
                'profile-title':
                    'base64:${base64.encode(utf8.encode('My Panel'))}',
              },
            );
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profilesProvider.future);
    return container;
  }

  setUp(() {
    store = MemoryProfileStore();
    served = {};
    requests = [];
  });

  test('imports links, selects the first and skips duplicates', () async {
    final c = await create();
    final controller = c.read(profilesProvider.notifier);

    final first = await controller.importText(
      '$vlessReality\n$trojanTls\nvless://bad',
    );
    expect(first.added, 2);
    expect(first.skipped, 1);

    final again = await controller.importText(vlessReality);
    expect(again.added, 0);

    final state = c.read(profilesProvider).value!;
    expect(state.profiles, hasLength(2));
    expect(state.selected!.name, 'Reality 🇳🇱');
    // Persisted.
    expect(store.state.profiles, hasLength(2));
  });

  test('a pasted http URL becomes a subscription', () async {
    served['https://sub.example.com/a'] = base64.encode(
      utf8.encode('$hy2\n$tuic'),
    );
    final c = await create();
    final outcome = await c
        .read(profilesProvider.notifier)
        .importText(' https://sub.example.com/a ');
    expect(outcome.added, 2);
    expect(outcome.subscription!.name, 'My Panel');
    expect(outcome.subscription!.info!.used, 30);
    expect(
      requests.single.headers['User-Agent'],
      startsWith('Simorgh/'),
    );
    final state = c.read(profilesProvider).value!;
    expect(state.profilesOf(outcome.subscription!.id), hasLength(2));
  });

  test('an Outline ssconf:// key becomes a subscription', () async {
    served['https://keys.example.com/k/1'] = jsonEncode({
      'server': '1.2.3.4',
      'server_port': 8388,
      'password': 'pw',
      'method': 'chacha20-ietf-poly1305',
      'prefix': '\u0016\u0003\u0001',
    });
    final c = await create();
    final outcome = await c
        .read(profilesProvider.notifier)
        .importText('ssconf://keys.example.com/k/1#My%20Outline');
    expect(outcome.added, 1);
    expect(outcome.subscription!.url, 'https://keys.example.com/k/1');
    expect(outcome.subscription!.name, 'My Outline');
    final config = outcome.profiles.single.config;
    expect(config.protocol, ProxyProtocol.shadowsocks);
    expect(config.name, 'My Outline');
    expect(config.outbound, {
      'type': 'shadowsocks',
      'server': '1.2.3.4',
      'server_port': 8388,
      'method': 'chacha20-ietf-poly1305',
      'password': 'pw',
    });

    // Refreshing re-reads the key and keeps the name.
    await c
        .read(profilesProvider.notifier)
        .updateSubscription(outcome.subscription!.id);
    final state = c.read(profilesProvider).value!;
    expect(state.profiles.single.name, 'My Outline');
  });

  test('an OpenVPN file is named after it and reports its login', () async {
    final c = await create();
    final controller = c.read(profilesProvider.notifier);
    final outcome = await controller.importText(ovpnTlsCrypt, name: 'Office');
    expect(outcome.profiles.single.name, 'Office');
    expect(outcome.profiles.single.config.needsLogin, isFalse);

    final seller = await controller.importText(ovpnProfile, name: 'de');
    final profile = seller.profiles.single;
    expect(profile.config.needsLogin, isTrue);
    await controller.replaceConfig(
      profile.id,
      profile.config.withLogin('bob', 'pw'),
    );
    final saved = store.state.profiles.firstWhere((p) => p.id == profile.id);
    expect(saved.config.needsLogin, isFalse);
    expect(saved.config.outbound['username'], 'bob');
  });

  test('update keeps ids of unchanged servers and the selection', () async {
    const url = 'https://sub.example.com/b';
    served[url] = '$hy2\n$tuic';
    final c = await create();
    final controller = c.read(profilesProvider.notifier);
    final added = await controller.addSubscription(url, name: 'Mine');
    final subId = added.subscription!.id;

    var state = c.read(profilesProvider).value!;
    final tuicProfile = state
        .profilesOf(subId)
        .firstWhere((p) => p.name == 'TUIC');
    await controller.select(tuicProfile.id);

    served[url] = '$tuic\n$ssSip002';
    final updated = await controller.updateSubscription(subId);
    expect(updated.added, 2);

    state = c.read(profilesProvider).value!;
    final names = state.profilesOf(subId).map((p) => p.name);
    expect(names, ['TUIC', 'SS 1']);
    expect(state.selectedId, tuicProfile.id);
    expect(state.subscriptions.single.name, 'Mine');
  });

  test('selection moves when the selected server disappears', () async {
    const url = 'https://sub.example.com/c';
    served[url] = hy2;
    final c = await create();
    final controller = c.read(profilesProvider.notifier);
    final added = await controller.addSubscription(url);
    served[url] = anytls;
    await controller.updateSubscription(added.subscription!.id);
    expect(c.read(profilesProvider).value!.selected!.name, 'AnyTLS');
  });

  test('auto mode survives imports and deletions', () async {
    const url = 'https://sub.example.com/auto';
    served[url] = '$hy2\n$anytls';
    final c = await create();
    final controller = c.read(profilesProvider.notifier);
    await controller.importText(trojanBare);
    await controller.select(ProfilesState.autoId);

    // New configs do not steal the selection from auto mode.
    final added = await controller.addSubscription(url);
    await controller.importText(tuic);
    var state = c.read(profilesProvider).value!;
    expect(state.isAuto, isTrue);
    expect(state.selected, isNull);
    expect(state.hasSelection, isTrue);

    await controller.deleteSubscription(added.subscription!.id);
    await controller.deleteProfile(state.manualProfiles().first.id);
    state = c.read(profilesProvider).value!;
    expect(state.isAuto, isTrue);

    // Nothing left to pick from: auto mode ends.
    await controller.deleteProfile(state.profiles.single.id);
    state = c.read(profilesProvider).value!;
    expect(state.selectedId, isNull);
    expect(state.hasSelection, isFalse);

    // And the next import selects normally again.
    await controller.importText(trojanBare);
    expect(c.read(profilesProvider).value!.selected!.name, 'bare');
  });

  test('only stale subscriptions are refreshed', () async {
    const fresh = 'https://sub.example.com/fresh';
    const stale = 'https://sub.example.com/stale';
    served[fresh] = hy2;
    served[stale] = tuic;
    final c = await create();
    final controller = c.read(profilesProvider.notifier);
    final a = (await controller.addSubscription(fresh)).subscription!;
    final b = (await controller.addSubscription(stale)).subscription!;
    requests.clear();

    final later = DateTime.now().add(const Duration(hours: 13));
    // Pretend [fresh] was refreshed just now, [stale] long ago.
    expect(
      await controller.updateDueSubscriptions(
        const Duration(hours: 12),
        now: later,
        skip: {a.id},
      ),
      {b.id},
    );
    expect(requests.map((r) => r.url.toString()), [stale]);

    // Nothing is due right after an update.
    requests.clear();
    expect(
      await controller.updateDueSubscriptions(const Duration(hours: 12)),
      isEmpty,
    );
    expect(requests, isEmpty);

    // A failing panel is reported as tried, without throwing.
    served.remove(stale);
    expect(
      await controller.updateDueSubscriptions(
        const Duration(hours: 1),
        now: later,
      ),
      {a.id, b.id},
    );
  });

  test('failed download surfaces SubscriptionException', () async {
    final c = await create();
    expect(
      () => c
          .read(profilesProvider.notifier)
          .addSubscription('https://missing.example.com'),
      throwsA(isA<SubscriptionException>()),
    );
  });

  test(
    'deleting a subscription removes its profiles and fixes selection',
    () async {
      const url = 'https://sub.example.com/d';
      served[url] = '$hy2\n$tuic';
      final c = await create();
      final controller = c.read(profilesProvider.notifier);
      final added = await controller.addSubscription(url);
      await controller.importText(trojanBare);
      await controller.deleteSubscription(added.subscription!.id);
      final state = c.read(profilesProvider).value!;
      expect(state.subscriptions, isEmpty);
      expect(state.profiles.single.name, 'bare');
      expect(state.selected!.name, 'bare');
    },
  );

  test('rename and delete profile', () async {
    final c = await create();
    final controller = c.read(profilesProvider.notifier);
    await controller.importText('$trojanBare\n$socks');
    final first = c.read(profilesProvider).value!.profiles.first;
    await controller.rename(first.id, 'Renamed');
    expect(c.read(profilesProvider).value!.profiles.first.name, 'Renamed');
    await controller.deleteProfile(first.id);
    final state = c.read(profilesProvider).value!;
    expect(state.profiles.single.name, 'SOCKS');
    expect(state.selected!.name, 'SOCKS');
  });

  test('state survives a JSON round trip', () async {
    final c = await create();
    await c
        .read(profilesProvider.notifier)
        .importText('$vlessReality\n$wireguard');
    final json =
        jsonDecode(jsonEncode(store.state.toJson())) as Map<String, Object?>;
    final restored = ProfilesState.fromJson(json);
    expect(restored.profiles.map((p) => p.name), ['Reality 🇳🇱', 'WARP']);
    expect(restored.selectedId, store.state.selectedId);
  });
}
