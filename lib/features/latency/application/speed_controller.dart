import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../connection/application/vpn_controller.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../network/application/internet_reach.dart';
import '../data/speed_tester.dart';
import '../domain/speed_result.dart';
import 'tester_lock.dart';

final speedProvider = NotifierProvider<SpeedController, SpeedState>(
  SpeedController.new,
);

/// Builds the tester for a run; overridable in tests.
final speedTesterFactoryProvider = Provider<SpeedTester Function()>(
  (ref) =>
      () => SpeedTester(
        platform: ref.read(vpnPlatformProvider),
        options: ref.read(effectiveCoreOptionsProvider),
      ),
);

class SpeedController extends Notifier<SpeedState> {
  static const _key = 'speed.results';

  StreamSubscription<SpeedUpdate>? _run;

  /// Completes when the current run ends, finished or cancelled.
  Completer<void>? _done;

  @override
  SpeedState build() {
    ref.onDispose(() => _run?.cancel());
    return SpeedState(results: _load());
  }

  /// Measures the given profiles one after another. Ignored while another
  /// speed run is in progress.
  Future<void> test(Iterable<String> ids) async {
    if (_done != null) return;
    final done = _done = Completer<void>();
    final profiles = (await ref.read(profilesProvider.future)).profiles;
    final wanted = ids.toSet();
    final targets = {
      for (final p in profiles)
        if (wanted.contains(p.id)) p.id: p.config,
    };
    if (!identical(_done, done) || targets.isEmpty) {
      _finish(done);
      return;
    }

    state = state.copyWith(
      current: () => targets.keys.first,
      total: targets.length,
      done: 0,
    );
    // The lock is held until the test core is really stopped, not just
    // until the UI considers the run over.
    await ref.read(testerLockProvider).run(() async {
      if (!identical(_done, done)) return;
      final released = _released = Completer<void>();
      void release() {
        _finish(done);
        if (!released.isCompleted) released.complete();
      }

      // Servers report in test order (rejected ones first), so the head
      // of this queue is the one being measured.
      final remaining = targets.keys.toList();
      _run = ref
          .read(speedTesterFactoryProvider)()
          .run(targets)
          .listen(
            (update) {
              remaining.remove(update.id);
              state = state.copyWith(
                results: {...state.results, update.id: update.result},
                done: state.done + 1,
                current: () => remaining.firstOrNull,
              );
            },
            onDone: release,
            onError: (Object _) => release(),
            cancelOnError: true,
          );
      await released.future;
    });
  }

  /// Completes when the running tester has released the test core.
  Completer<void>? _released;

  /// Stops the current run, keeping results gathered so far. Returns once
  /// the test core is stopped.
  Future<void> cancel() async {
    final run = _run;
    _run = null;
    final done = _done;
    if (done != null) _finish(done);
    if (run != null) await run.cancel();
    final released = _released;
    if (released != null && !released.isCompleted) released.complete();
  }

  void _finish(Completer<void> done) {
    if (!identical(_done, done)) return;
    _done = null;
    state = state.copyWith(current: () => null, total: 0, done: 0);
    done.complete();
    unawaited(_save());
  }

  Map<String, SpeedResult> _load() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      return {
        for (final MapEntry(:key, :value) in json.entries)
          key as String: ?SpeedResult.fromJson(value),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> _save() async {
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
