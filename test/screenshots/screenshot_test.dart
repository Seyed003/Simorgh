@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:aghelan_ghiamat/app.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/domain/traffic.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
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

  for (final (lang, theme, connected, width) in [
    ('fa', 'dark', true, 412.0),
    ('fa', 'light', false, 412.0),
    ('en', 'light', true, 412.0),
    ('en', 'dark', true, 1280.0),
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
            'build/screenshots/home_${lang}_${theme}_${connected ? 'on' : 'off'}_${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
