import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/network/application/internet_reach.dart';
import 'package:aghelan_ghiamat/features/network/data/reach_probe.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

/// A probe whose checks answer from [answers] by host; hosts missing there
/// never answer at all.
ReachProbe _probe(Map<String, bool> answers, {List<String>? asked}) =>
    ReachProbe(
      foreign: const ['https://abroad-1/', 'https://abroad-2/'],
      domestic: const ['tcp://home-1:53', 'https://home-2/'],
      check: (target, _) {
        asked?.add(target.host);
        final answer = answers[target.host];
        if (answer == null) return Completer<bool>().future;
        if (target.host == 'home-2' && !answer) {
          return Future.error(const SocketException('reset'));
        }
        return Future.value(answer);
      },
    );

void main() {
  group('probe', () {
    test('open as soon as anything abroad answers', () async {
      // The Iranian targets never answer; the result does not wait for them.
      expect(
        await _probe({'abroad-1': false, 'abroad-2': true}).run(),
        InternetReach.open,
      );
    });

    test('national internet: only Iranian addresses answer', () async {
      expect(
        await _probe({
          'abroad-1': false,
          'abroad-2': false,
          'home-1': false,
          'home-2': true,
        }).run(),
        InternetReach.domesticOnly,
      );
    });

    test('offline when nothing answers, errors included', () async {
      final asked = <String>[];
      expect(
        await _probe({
          'abroad-1': false,
          'abroad-2': false,
          'home-1': false,
          'home-2': false,
        }, asked: asked).run(),
        InternetReach.offline,
      );
      expect(asked, containsAll(['abroad-1', 'abroad-2', 'home-1', 'home-2']));
    });

    test('real checks: TCP connects and any HTTP answer', () async {
      final tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(tcp.close);
      tcp.listen((s) => s.destroy());
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => http.close(force: true));
      http.listen((request) {
        request.response.statusCode = HttpStatus.notFound;
        unawaited(request.response.close());
      });
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = closed.port;
      await closed.close();

      const t = Duration(seconds: 2);
      expect(
        await reachable(Uri.parse('tcp://127.0.0.1:${tcp.port}'), t),
        isTrue,
      );
      expect(
        await reachable(Uri.parse('tcp://127.0.0.1:$closedPort'), t),
        isFalse,
      );
      expect(
        await reachable(Uri.parse('http://127.0.0.1:${http.port}/'), t),
        isTrue,
      );
      expect(
        await reachable(Uri.parse('http://127.0.0.1:$closedPort/'), t),
        isFalse,
      );
      // TLS must check out: a plain HTTP server is no HTTPS site.
      expect(
        await reachable(Uri.parse('https://127.0.0.1:${http.port}/'), t),
        isFalse,
      );
    });
  });

  group('on the national internet', () {
    Future<ProviderContainer> container(
      InternetReach reach, {
      FakeVpnPlatform? platform,
    }) async {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await mockPreferences()),
          reachProbeProvider.overrideWithValue(FakeReachProbe(reach)),
          profileStoreProvider.overrideWithValue(MemoryProfileStore()),
          vpnPlatformProvider.overrideWithValue(platform ?? FakeVpnPlatform()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a foreign direct DNS gives way to the system resolver', () async {
      final c = await container(InternetReach.domesticOnly);
      expect(c.read(effectiveCoreOptionsProvider).directDns, '1.1.1.1');
      await c.read(internetReachProvider.notifier).check();
      expect(c.read(internetReachProvider).domesticOnly, isTrue);
      expect(c.read(effectiveCoreOptionsProvider).directDns, 'local');
      // The setting itself is untouched.
      expect(c.read(coreOptionsProvider).directDns, '1.1.1.1');

      // An Iranian resolver keeps working: left as chosen.
      await c
          .read(coreOptionsProvider.notifier)
          .update((o) => o.copyWith(directDns: '178.22.122.100'));
      expect(c.read(effectiveCoreOptionsProvider).directDns, '178.22.122.100');
    });

    test('nothing changes on an open internet', () async {
      final c = await container(InternetReach.open);
      await c.read(internetReachProvider.notifier).check();
      expect(c.read(internetReachProvider).reach, InternetReach.open);
      expect(c.read(effectiveCoreOptionsProvider).directDns, '1.1.1.1');
    });

    test('simulate pins the reach, then hands control back', () async {
      // The real probe would say "open"; the simulation overrides it.
      final c = await container(InternetReach.open);
      final reach = c.read(internetReachProvider.notifier);

      reach.simulate(InternetReach.domesticOnly);
      expect(c.read(internetReachProvider).domesticOnly, isTrue);
      expect(c.read(effectiveCoreOptionsProvider).directDns, 'local');

      // A real check (e.g. from the app shell on resume) does not undo it.
      await reach.check();
      expect(c.read(internetReachProvider).domesticOnly, isTrue);

      // Handing control back re-runs the probe: open again.
      reach.simulate(null);
      await reach.check();
      expect(c.read(internetReachProvider).reach, InternetReach.open);
      expect(c.read(internetReachProvider).simulated, isNull);
      expect(c.read(effectiveCoreOptionsProvider).directDns, '1.1.1.1');
    });

    test('refresh skips a fresh result', () async {
      var runs = 0;
      final c = ProviderContainer(
        overrides: [
          reachProbeProvider.overrideWithValue(
            ReachProbe(
              foreign: const ['https://abroad/'],
              domestic: const [],
              check: (_, _) async {
                runs++;
                return true;
              },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      final reach = c.read(internetReachProvider.notifier);
      await reach.refresh();
      await reach.refresh();
      expect(runs, 1);
      await reach.check();
      expect(runs, 2);
    });

    test('connecting resolves server names with the system DNS', () async {
      final platform = FakeVpnPlatform();
      final c = await container(InternetReach.domesticOnly, platform: platform);
      await c.read(internetReachProvider.notifier).check();
      await c.read(profilesProvider.future);
      await c.read(profilesProvider.notifier).importText(vlessWs);
      await c.read(vpnControllerProvider.notifier).connect();

      final config = jsonDecode(
        platform.requests.single.configJson,
      ) as Map<String, Object?>;
      final servers = ((config['dns']! as Map)['servers']! as List)
          .cast<Map<String, Object?>>();
      final direct = servers.singleWhere((s) => s['tag'] == 'dns-direct');
      expect(direct['type'], 'local');
    });
  });
}
