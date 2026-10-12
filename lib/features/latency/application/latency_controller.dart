import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../connection/application/vpn_controller.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../settings/application/core_options_controller.dart';
import '../data/latency_tester.dart';
import '../domain/latency_result.dart';
import 'tester_lock.dart';

final latencyProvider = NotifierProvider<LatencyController, LatencyState>(
  LatencyController.new,
);

/// Builds the tester for a run; overridable in tests.
final latencyTesterFactoryProvider = Provider<LatencyTester Function()>(
  (ref) =>
      () => LatencyTester(
        platform: ref.read(vpnPlatformProvider),
        options: ref.read(coreOptionsProvider),
      ),
);

class LatencyController extends Notifier<LatencyState> {
  static const _key = 'latency.results';

  StreamSubscription<LatencyUpdate>? _run;

  /// Completes when the current run ends, finished or cancelled.
  Completer<void>? _done;

  @override
  LatencyState build() {
    ref.onDispose(() => _run?.cancel());
    return LatencyState(results: _load());
  }

  /// Tests every stored profile.
  Future<void> testAll() async {
    final profiles = (await ref.read(profilesProvider.future)).profiles;
    await test(profiles.map((p) => p.id));
  }

  /// Tests the given profiles. While another run is in progress this only
  /// waits for that run instead of starting a second one.
  Future<void> test(Iterable<String> ids) async {
    if (_done case final running?) return running.future;
    final done = _done = Completer<void>();
    final profiles = (await ref.read(profilesProvider.future)).profiles;
    if (!identical(_done, done)) return; // cancelled meanwhile
    final wanted = ids.toSet();
    final targets = {
      for (final p in profiles)
        if (wanted.contains(p.id)) p.id: p.config,
    };
    if (targets.isEmpty) {
      _done = null;
      done.complete();
      return;
    }

    state = state.copyWith(
      testing: targets.keys.toSet(),
      total: targets.length,
      done: 0,
    );
    await ref.read(testerLockProvider).run(() {
      // Cancelled while waiting for a speed test to finish.
      if (!identical(_done, done)) return Future<void>.value();
      _run = ref
          .read(latencyTesterFactoryProvider)()
          .run(targets)
          .listen(
            (update) {
              state = state.copyWith(
                results: {...state.results, update.id: update.result},
                testing: {...state.testing}..remove(update.id),
                done: state.done + 1,
              );
            },
            onDone: _finish,
            onError: (Object _) => _finish(),
            cancelOnError: true,
          );
      return done.future;
    });
  }

  /// Stops the current run, keeping results gathered so far.
  Future<void> cancel() async {
    final run = _run;
    _run = null;
    await run?.cancel();
    _finish();
  }

  void _finish() {
    final done = _done;
    if (done == null) return;
    _done = null;
    _run = null;
    state = state.copyWith(testing: const {});
    done.complete();
    unawaited(_save());
  }

  Map<String, LatencyResult> _load() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      return {
        for (final MapEntry(:key, :value) in json.entries)
          key as String: ?LatencyResult.fromJson(value),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> _save() async {
    // Forget results of profiles that no longer exist.
    final ids =
        ref.read(profilesProvider).value?.profiles.map((p) => p.id).toSet() ??
        state.results.keys.toSet();
    final json = {
      for (final MapEntry(:key, :value) in state.results.entries)
        if (ids.contains(key)) key: value.toJson(),
    };
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(json));
  }
}
