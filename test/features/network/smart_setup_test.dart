import 'package:aghelan_ghiamat/core/platform/system_bridge.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/proxy_config.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:aghelan_ghiamat/features/network/application/network_tuning.dart';
import 'package:aghelan_ghiamat/features/network/application/smart_setup.dart';
import 'package:aghelan_ghiamat/features/network/domain/network_identity.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:aghelan_ghiamat/core/theme/app_theme.dart';
import 'package:aghelan_ghiamat/features/network/presentation/smart_setup_page.dart';
import 'package:aghelan_ghiamat/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

class _OnNetwork extends SystemBridge {
  const _OnNetwork(this.identity);

  final NetworkIdentity identity;

  @override
  Future<NetworkIdentity> network() async => identity;
}

const _irancell = NetworkIdentity(
  kind: NetworkKind.cellular,
  operatorName: 'MTN Irancell',
  mccMnc: '43235',
);

void main() {
  test('network keys and names', () {
    expect(_irancell.key, 'cellular:43235');
    expect(_irancell.operatorLabel('fa'), 'ایرانسل');
    expect(_irancell.operatorLabel('en'), 'Irancell');
    const other = NetworkIdentity(
      kind: NetworkKind.cellular,
      operatorName: 'Foo',
      mccMnc: '99999',
    );
    expect(other.operatorLabel('fa'), 'Foo');
    expect(const NetworkIdentity(kind: NetworkKind.wifi).key, 'wifi');
    expect(
      NetworkIdentity.fromMap(const {'kind': 'wifi', 'operator': ' '}),
      const NetworkIdentity(kind: NetworkKind.wifi),
    );
  });

  test('the mode reaching most servers wins; ties prefer no fragment', () {
    ModeScore s(TlsFragmentMode m, int ok, [int? ms]) =>
        ModeScore(mode: m, ok: ok, total: 5, medianMs: ms);
    expect(
      pickBestMode([
        s(TlsFragmentMode.off, 1, 100),
        s(TlsFragmentMode.record, 4, 300),
        s(TlsFragmentMode.tcp, 4, 200),
      ]),
      TlsFragmentMode.tcp,
    );
    expect(
      pickBestMode([
        s(TlsFragmentMode.off, 3, 500),
        s(TlsFragmentMode.record, 3, 100),
        s(TlsFragmentMode.tcp, 2, 50),
      ]),
      TlsFragmentMode.off,
    );
    expect(
      pickBestMode([
        s(TlsFragmentMode.off, 0),
        s(TlsFragmentMode.record, 0),
        s(TlsFragmentMode.tcp, 0),
      ]),
      isNull,
    );
  });

  test('variants carry exactly one fragment mode', () {
    final sing = LinkParser.parse(vlessWs);
    Map<String, Object?> tls(ProxyConfig c) =>
        (c.outbound['tls']! as Map).cast<String, Object?>();
    expect(
      tls(withFragment(sing, TlsFragmentMode.record))['record_fragment'],
      isTrue,
    );
    expect(tls(withFragment(sing, TlsFragmentMode.tcp))['fragment'], isTrue);
    final off = tls(
      withFragment(
        withFragment(sing, TlsFragmentMode.tcp),
        TlsFragmentMode.off,
      ),
    );
    expect(off.containsKey('fragment'), isFalse);
    expect(off.containsKey('record_fragment'), isFalse);

    final xray = LinkParser.parse(vlessXhttp);
    expect(
      (withFragment(xray, TlsFragmentMode.tcp).outbound['fragment']!
          as Map)['interval'],
      '10-20',
    );
    expect(
      withFragment(xray, TlsFragmentMode.off).outbound['fragment'],
      isNull,
    );
  });

  group('with a device', () {
    late List<Map<String, ProxyConfig>> probes;

    Future<ProviderContainer> create({
      required String links,
      required Set<TlsFragmentMode> working,
    }) async {
      probes = [];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({}),
          ),
          profileStoreProvider.overrideWithValue(MemoryProfileStore()),
          vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
          systemBridgeProvider.overrideWithValue(const _OnNetwork(_irancell)),
          fragmentProbeProvider.overrideWithValue((variants) async {
            probes.add(variants);
            return {
              for (final id in variants.keys)
                id: working.any((m) => id.startsWith('${m.name}|'))
                    ? LatencyResult.success(120, DateTime(2026))
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
      await container.read(profilesProvider.notifier).importText(links);
      return container;
    }

    test('finds, applies and remembers the mode for the operator', () async {
      final c = await create(
        links: '$vlessWs\n$trojanTls\n$hy2',
        working: {TlsFragmentMode.tcp},
      );
      await c.read(smartSetupProvider.notifier).run();
      final state = c.read(smartSetupProvider);
      expect(state.phase, SmartSetupPhase.done);
      expect(state.chosen, TlsFragmentMode.tcp);
      // Hysteria2 has no TLS-over-TCP to fragment: 2 servers x 3 modes.
      expect(probes.single, hasLength(6));
      expect(state.scores.map((s) => s.ok), [0, 0, 2]);
      expect(c.read(coreOptionsProvider).tlsFragment, TlsFragmentMode.tcp);
      final tuning = c.read(networkTuningProvider).byNetwork['cellular:43235']!;
      expect(tuning.tlsFragment, TlsFragmentMode.tcp);
      expect(tuning.measured, isTrue);
    });

    test(
      'says so when nothing gets through or nothing can be tested',
      () async {
        final c = await create(links: vlessWs, working: {});
        await c.read(smartSetupProvider.notifier).run();
        expect(c.read(smartSetupProvider).phase, SmartSetupPhase.nothingWorks);
        expect(c.read(coreOptionsProvider).tlsFragment, TlsFragmentMode.off);

        final none = await create(
          links: hy2,
          working: TlsFragmentMode.values.toSet(),
        );
        await none.read(smartSetupProvider.notifier).run();
        expect(none.read(smartSetupProvider).phase, SmartSetupPhase.noServers);
      },
    );

    test('connecting on a remembered network uses its setting', () async {
      final c = await create(links: trojanBare, working: {});
      await c
          .read(networkTuningProvider.notifier)
          .remember(_irancell, TlsFragmentMode.record);
      await c.read(vpnControllerProvider.notifier).connect();
      expect(c.read(coreOptionsProvider).tlsFragment, TlsFragmentMode.record);

      // Switched off: the current setting stays.
      await c.read(vpnControllerProvider.notifier).disconnect();
      await c.read(networkTuningProvider.notifier).setAutoSwitch(false);
      await c
          .read(coreOptionsProvider.notifier)
          .update((o) => o.copyWith(tlsFragment: TlsFragmentMode.off));
      await c.read(vpnControllerProvider.notifier).connect();
      expect(c.read(coreOptionsProvider).tlsFragment, TlsFragmentMode.off);
    });

    test('remembered settings survive a restart', () async {
      final c = await create(links: trojanBare, working: {});
      await c
          .read(networkTuningProvider.notifier)
          .remember(_irancell, TlsFragmentMode.tcp, measured: true);
      final prefs = c.read(sharedPreferencesProvider);
      final again = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({
              'network.tuning': prefs.getString('network.tuning')!,
            }),
          ),
        ],
      );
      addTearDown(again.dispose);
      expect(
        again
            .read(networkTuningProvider)
            .byNetwork['cellular:43235']!
            .tlsFragment,
        TlsFragmentMode.tcp,
      );
    });
  });

  testWidgets('the page runs the test and shows the result', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({'settings.language': 'en'}),
          ),
          profileStoreProvider.overrideWithValue(MemoryProfileStore()),
          vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
          systemBridgeProvider.overrideWithValue(const _OnNetwork(_irancell)),
          fragmentProbeProvider.overrideWithValue(
            (variants) async => {
              for (final id in variants.keys)
                id: LatencyResult.success(90, DateTime(2026)),
            },
          ),
        ],
      );
      await container.read(profilesProvider.future);
      await container.read(profilesProvider.notifier).importText(vlessWs);
    });
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SmartSetupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Irancell'), findsOneWidget);
    expect(find.text('Not tested on this network yet'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Start test'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Best on Irancell: No fragment. Applied.'),
      findsOneWidget,
    );
    expect(find.text('Remembered here: No fragment'), findsOneWidget);
    expect(find.text('1 of 1 servers'), findsNWidgets(3));
  });
}
