import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/data/subscription_client.dart';
import 'package:aghelan_ghiamat/features/warp/application/free_servers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

/// A plain-text free list, the universal share-link format these public
/// aggregators return.
final freeList = [vlessReality, vlessWs, trojanXhttp].join('\n');

Future<ProviderContainer> container(MockClient client) async =>
    ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await mockPreferences({})),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
        httpClientProvider.overrideWithValue(client),
      ],
    );

void main() {
  test('imports curated free servers and remembers them', () async {
    final c = await container(
      MockClient((_) async => http.Response(freeList, 200)),
    );
    addTearDown(c.dispose);
    final free = c.read(freeServersServiceProvider);

    expect(await free.exists(), isFalse);
    final added = await free.ensure(name: 'Free servers');
    expect(added, greaterThan(0));
    // exists() uses the same (normalised) url match ensure() stores under.
    expect(await free.exists(), isTrue);

    final state = await c.read(profilesProvider.future);
    expect(state.subscriptions, hasLength(1));
    expect(state.profilesOf(state.subscriptions.single.id), isNotEmpty);
  });

  test('falls back to the next source when the first fails', () async {
    final tried = <String>[];
    final c = await container(
      MockClient((req) async {
        tried.add(req.url.toString());
        if (req.url.toString().contains('0xRadikal')) {
          return http.Response('not found', 404);
        }
        return http.Response(freeList, 200);
      }),
    );
    addTearDown(c.dispose);

    final added = await c.read(freeServersServiceProvider).ensure(name: 'F');
    expect(added, greaterThan(0));
    expect(tried, hasLength(2)); // first source failed, second was tried
    expect(tried.first, contains('0xRadikal'));
    final state = await c.read(profilesProvider.future);
    expect(state.subscriptions.single.url, contains('mahdibland'));
  });

  test('refreshes the existing subscription instead of duplicating', () async {
    final c = await container(
      MockClient((_) async => http.Response(freeList, 200)),
    );
    addTearDown(c.dispose);
    final free = c.read(freeServersServiceProvider);

    await free.ensure(name: 'Free servers');
    await free.ensure(name: 'Free servers');

    final state = await c.read(profilesProvider.future);
    expect(state.subscriptions, hasLength(1));
  });

  test('every source is a valid https jsDelivr URL', () {
    expect(FreeServersService.sources, isNotEmpty);
    for (final url in FreeServersService.sources) {
      final uri = Uri.parse(url);
      expect(uri.isScheme('https'), isTrue);
      expect(uri.host, 'cdn.jsdelivr.net');
    }
  });
}
