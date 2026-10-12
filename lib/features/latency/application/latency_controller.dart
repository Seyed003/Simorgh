import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../connection/application/vpn_controller.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../settings/application/core_options_controller.dart';
import '../data/latency_tester.dart';
import '../domain/latency_result.dart';

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

  /// Tests the given profiles. Ignored while another run is in progress.
  Future<void> test(Iterable<String> ids) async {
    if (state.running) return;
    final profiles = (await ref.read(profilesProvider.future)).profiles;
    final wanted = ids.toSet();
    final targets = {
      for (final p in profiles)
        if (wanted.contains(p.id)) p.id: p.config,
    };
    if (targets.isEmpty) return;

    state = state.copyWith(
      testing: targets.keys.toSet(),
      total: targets.length,
      done: 0,
    );
    final completer = Completer<void>();
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
          onDone: completer.complete,
          onError: (Object _) => completer.complete(),
          cancelOnError: true,
        );
    await completer.future;
    _finish();
  }

  /// Stops the current run, keeping results gathered so far.
  Future<void> cancel() async {
    await _run?.cancel();
    _finish();
  }

  void _finish() {
    _run = null;
    state = state.copyWith(testing: const {});
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
