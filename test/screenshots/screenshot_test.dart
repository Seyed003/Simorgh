@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/theme/app_theme.dart';
import 'package:aghelan_ghiamat/features/settings/application/settings_controller.dart';
import 'package:aghelan_ghiamat/features/usage/presentation/usage_page.dart';
import 'package:aghelan_ghiamat/l10n/generated/app_localizations.dart';
import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';
import 'package:aghelan_ghiamat/features/latency/application/latency_controller.dart';
import 'package:aghelan_ghiamat/features/latency/application/speed_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profiles_state.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/singbox/fixtures.dart';
import '../fakes.dart';
import '../helpers.dart';

/// Renders screenshots of the home page into build/screenshots:
///
///     SCREENSHOTS=1 flutter test test/screenshots
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  await load('Vazirmatn', [
    'assets/fonts/Vazirmatn-Regular.ttf',
    'assets/fonts/Vazirmatn-Medium.ttf',
    'assets/fonts/Vazirmatn-Bold.ttf',
  ]);
  await load('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

void main() {
  final skip = Platform.environment['SCREENSHOTS'] == null
      ? 'set SCREENSHOTS=1 to render screenshots'
      : null;
  setUpAll(_loadFonts);

  for (final (lang, theme, connected, width, auto) in [
    ('fa', 'dark', true, 412.0, true),
    ('fa', 'light', false, 412.0, false),
    ('en', 'light', true, 412.0, false),
    ('en', 'dark', true, 1280.0, false),
  ]) {
    testWidgets(
      'home $lang $theme ${connected ? 'connected' : 'idle'} $width',
      skip: skip != null,
      (tester) async {
        final size = Size(width, width > 1000 ? 800 : 900);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await mockPreferences({
          'settings.language': lang,
          'settings.theme_mode': theme,
        });
        final platform = FakeVpnPlatform();
        String? activeAutoId;
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            profileStoreProvider.overrideWithValue(MemoryProfileStore()),
            vpnPlatformProvider.overrideWithValue(platform),
            trafficProvider.overrideWith(
              (ref) => Stream.value(
                connected
                    ? const TrafficStats(
                        uploadSpeed: 184320,
                        downloadSpeed: 4404019,
                        uploadTotal: 12582912,
                        downloadTotal: 228589568,
                      )
                    : TrafficStats.zero,
              ),
            ),
            autoActiveProfileIdProvider.overrideWith(
              (ref) => Stream.value(activeAutoId),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.runAsync(() async {
          await container.read(profilesProvider.future);
          await container
              .read(profilesProvider.notifier)
              .importText(
                '$vlessReality\n$vmessWsTls\n$hy2\n$tuic\n$wireguard',
              );
          final ids = container
              .read(profilesProvider)
              .value!
              .profiles
              .map((p) => p.id)
              .toList();
          final t = DateTime.now().millisecondsSinceEpoch;
          await prefs.setString(
            'latency.results',
            '{"${ids[0]}":{"d":142,"t":$t},"${ids[1]}":{"d":486,"t":$t},"${ids[2]}":{"f":"unreachable","t":$t},"${ids[3]}":{"d":1240,"t":$t}}',
          );
          await prefs.setString(
            'speed.results',
            '{"${ids[0]}":{"b":3062500,"t":$t},"${ids[1]}":{"b":812000,"t":$t}}',
          );
          container
            ..invalidate(latencyProvider)
            ..invalidate(speedProvider);
          if (auto) {
            await container
                .read(profilesProvider.notifier)
                .select(ProfilesState.autoId);
            activeAutoId = ids[0];
          }
          if (connected) {
            await container.read(vpnControllerProvider.notifier).connect();
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        });
        expect(
          container.read(vpnControllerProvider).status,
          connected ? VpnStatus.connected : VpnStatus.disconnected,
        );

        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('shot'),
            child: UncontrolledProviderScope(
              container: container,
              child: const AghelanApp(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shot')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/screenshots/home_${lang}_${theme}_${connected ? 'on' : 'off'}${auto ? '_auto' : ''}_${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('settings fa light', skip: skip != null, (tester) async {
    const size = Size(412, 2000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await mockPreferences({
      'settings.language': 'fa',
      'settings.theme_mode': 'light',
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(coreOptionsProvider.notifier)
          .update(
            (o) => o.copyWith(tlsFragment: TlsFragmentMode.record, mux: true),
          ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(
          container: container,
          child: const AghelanApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/screenshots/settings_fa_light.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (lang, theme) in [('fa', 'light'), ('en', 'dark')]) {
    testWidgets('usage $lang $theme', skip: skip != null, (tester) async {
      tester.view.physicalSize = const Size(412, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final today = DateTime(2026, 10, 12);
      const mb = 1024 * 1024;
      const daily = [
        120,
        340,
        0,
        80,
        610,
        1250,
        430,
        95,
        0,
        720,
        260,
        180,
        905,
        310,
      ];
      final days = {
        for (final (i, value) in daily.indexed)
          today
              .subtract(Duration(days: daily.length - 1 - i))
              .toIso8601String()
              .substring(0, 10): [
            value * mb ~/ 12,
            value * mb,
          ],
      };
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences({
              'settings.language': lang,
              'settings.theme_mode': theme,
              'usage.daily': jsonEncode(days),
            }),
          ),
          profileStoreProvider.overrideWithValue(MemoryProfileStore()),
          vpnPlatformProvider.overrideWithValue(FakeVpnPlatform()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(settingsProvider);
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: settings.themeMode,
                  locale: settings.language.locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: UsagePage(today: today),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Select the busiest day to show the detail line.
      await tester.tapAt(
        tester.getBottomLeft(find.byType(GestureDetector).at(5)) +
            const Offset(4, -4),
      );
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('shot')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/screenshots/usage_${lang}_$theme.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    });
  }
}
