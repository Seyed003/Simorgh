import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/data/subscription_client.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profile.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profiles_state.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/subscription.dart';
import 'package:aghelan_ghiamat/features/updates/data/update_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

void main() {
  Future<(ProviderContainer, List<Uri>)> pump(
    WidgetTester tester, {
    required DateTime lastUpdated,
    Map<String, Object> prefs = const {},
  }) async {
    final requests = <Uri>[];
    final store = MemoryProfileStore(
      ProfilesState(
        subscriptions: [
          Subscription(
            id: 's1',
            name: 'Panel',
            url: 'https://sub.example.com/x',
            lastUpdated: lastUpdated,
          ),
        ],
        profiles: [
          Profile(
            id: 'old',
            config: LinkParser.parse(trojanBare),
            createdAt: lastUpdated,
            subscriptionId: 's1',
          ),
        ],
        selectedId: 'old',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await mockPreferences({'settings.language': 'en', ...prefs}),
        ),
        profileStoreProvider.overrideWithValue(store),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            requests.add(request.url);
            return http.Response(hy2, 200);
          }),
        ),
        // The app's own update check is not a subscription request.
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(MockClient((_) async => http.Response('', 404))),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AghelanApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (container, requests);
  }

  testWidgets('a stale subscription is refreshed on start', (tester) async {
    final (container, requests) = await pump(
      tester,
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    );
    expect(requests.single.host, 'sub.example.com');
    final state = container.read(profilesProvider).value!;
    expect(state.profilesOf('s1').single.name, 'HY2');
  });

  testWidgets('a fresh one is left alone', (tester) async {
    final (_, requests) = await pump(
      tester,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(requests, isEmpty);
  });

  testWidgets('nothing happens when auto-update is off', (tester) async {
    final (_, requests) = await pump(
      tester,
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
      prefs: {'settings.subscription_update_hours': 0},
    );
    expect(requests, isEmpty);
  });

  testWidgets('coming back to the foreground checks again', (tester) async {
    final (container, requests) = await pump(
      tester,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
    );
    expect(requests, isEmpty);
    // Make it stale, then resume the app.
    await container
        .read(profilesProvider.notifier)
        .renameSubscription('s1', 'x');
    final store = container.read(profileStoreProvider) as MemoryProfileStore;
    final stale = store.state.subscriptions.single;
    store.state = store.state.copyWith(
      subscriptions: [
        Subscription(
          id: stale.id,
          name: stale.name,
          url: stale.url,
          lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );
    container.invalidate(profilesProvider);
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
  });
}
