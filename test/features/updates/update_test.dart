import 'dart:convert';
import 'dart:io';

import 'package:aghelan_ghiamat/core/constants/app_info.dart';
import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/updates/application/update_controller.dart';
import 'package:aghelan_ghiamat/features/updates/data/update_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers.dart';

void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(AppInfo.version, version);
  });

  test('version comparison', () {
    expect(compareVersions('0.10.0', '0.9.9'), 1);
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('0.2.0-beta', '0.2.0'), 0);
    expect(compareVersions('0.1.9', '0.2'), -1);
  });

  group('update check', () {
    late int calls;
    Future<ProviderContainer> create(
      String tag, {
      int status = 200,
      Map<String, Object> prefs = const {},
      String host = 'https://github.com/Seyed003/aghelan-ghiamat',
    }) async {
      calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.toString(), AppInfo.latestReleaseApi);
        return http.Response(
          jsonEncode({'tag_name': tag, 'html_url': '$host/releases/tag/$tag'}),
          status,
        );
      });
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await mockPreferences(prefs),
          ),
          updateCheckerProvider.overrideWithValue(UpdateChecker(client)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a release link elsewhere becomes our releases page', () async {
      final c = await create('v99.0.0', host: 'https://evil.example/x');
      final release = await c.read(updateProvider.notifier).check();
      expect(release!.url, AppInfo.releasesPage);
    });

    test('finds a newer release and can hide it', () async {
      final c = await create('v99.0.0');
      final release = await c.read(updateProvider.notifier).check();
      expect(release!.version, '99.0.0');
      expect(c.read(updateProvider).available!.url, endsWith('v99.0.0'));
      await c.read(updateProvider.notifier).dismiss();
      expect(c.read(updateProvider).available, isNull);
      // Still dismissed on the next check.
      await c.read(updateProvider.notifier).check();
      expect(c.read(updateProvider).available, isNull);
    });

    test('same or older version, or a private repository: nothing', () async {
      for (final (tag, status) in [
        ('v${AppInfo.version}', 200),
        ('v0.0.1', 200),
        ('v99.0.0', 404),
      ]) {
        final c = await create(tag, status: status);
        expect(await c.read(updateProvider.notifier).check(), isNull);
        expect(c.read(updateProvider).available, isNull);
      }
    });

    test('checks automatically at most once a day', () async {
      final now = DateTime(2026, 10, 12, 12);
      final c = await create('v99.0.0');
      final updates = c.read(updateProvider.notifier);
      await updates.checkAutomatically(now: now);
      await updates.checkAutomatically(now: now.add(const Duration(hours: 3)));
      expect(calls, 1);
      await updates.checkAutomatically(now: now.add(const Duration(days: 2)));
      expect(calls, 2);
    });
  });
}
