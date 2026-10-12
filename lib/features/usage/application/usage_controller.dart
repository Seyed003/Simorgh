import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/storage/preferences.dart';
import '../../connection/application/vpn_controller.dart';
import '../../connection/data/clash_api_client.dart';
import '../domain/usage.dart';

final usageProvider = NotifierProvider<UsageController, UsageState>(
  UsageController.new,
);

/// Samples the running core's totals while connected. Watched by the home
/// screen; usage while the app was closed is caught up on the next sample
/// because the core's totals keep counting.
final usageRecorderProvider = Provider.autoDispose<void>((ref) {
  final api = ref.watch(
    vpnControllerProvider.select((s) => s.isConnected ? s.clashApi : null),
  );
  if (api == null) return;
  final controller = ref.read(usageProvider.notifier);
  unawaited(controller.sample(api));
  // The live traffic stream ticks once a second while connected; sampling
  // on every 15th tick needs no timer of its own.
  var ticks = 0;
  ref.listen(trafficProvider, (_, _) {
    if (++ticks % 15 == 0) unawaited(controller.sample(api));
  });
});

class UsageController extends Notifier<UsageState> {
  static const _daysKey = 'usage.daily';
  static const _sessionKey = 'usage.session';

  /// Days older than this are dropped.
  static const keepDays = 90;

  /// Builds the API client; overridable in tests.
  ClashApiClient Function(ClashApiOptions) clientFactory = ClashApiClient.new;

  @override
  UsageState build() => UsageState(days: _load());

  /// Reads the core's totals and records what moved since the last sample.
  Future<void> sample(ClashApiOptions api) async {
    final totals = await clientFactory(api).totals();
    if (totals == null) return;
    await record('${api.port}:${api.secret}', totals.up, totals.down);
  }

  /// [session] identifies one run of the core; its totals only grow, so the
  /// difference to the previous sample is the new traffic. A new session
  /// (or totals that went down because the core restarted) counts in full.
  Future<void> record(String session, int up, int down, {DateTime? now}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    var (deltaUp, deltaDown) = (up, down);
    final raw = prefs.getString(_sessionKey);
    if (raw != null) {
      final last = jsonDecode(raw) as Map<String, Object?>;
      final lastUp = last['u'] as int? ?? 0;
      final lastDown = last['d'] as int? ?? 0;
      if (last['k'] == session && up >= lastUp && down >= lastDown) {
        (deltaUp, deltaDown) = (up - lastUp, down - lastDown);
      }
    }
    await prefs.setString(
      _sessionKey,
      jsonEncode({'k': session, 'u': up, 'd': down}),
    );
    if (deltaUp == 0 && deltaDown == 0) return;

    final today = UsageState.dayOf(now ?? DateTime.now());
    final oldest = today.subtract(const Duration(days: keepDays));
    final days = {
      for (final MapEntry(:key, :value) in state.days.entries)
        if (!key.isBefore(oldest)) key: value,
    };
    days[today] = (days[today] ?? const DayUsage()).add(deltaUp, deltaDown);
    state = UsageState(days: days);
    await _save();
  }

  Future<void> reset() async {
    state = const UsageState();
    await ref.read(sharedPreferencesProvider).remove(_daysKey);
  }

  Map<DateTime, DayUsage> _load() {
    final raw = ref.read(sharedPreferencesProvider).getString(_daysKey);
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      return {
        for (final MapEntry(:key, :value) in json.entries)
          if (DateTime.tryParse(key as String) case final day?
              when value is List && value.length == 2)
            day: DayUsage(up: value[0] as int, down: value[1] as int),
      };
    } on Object {
      return const {};
    }
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(
        _daysKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in state.days.entries)
            '${key.year.toString().padLeft(4, '0')}-'
                '${key.month.toString().padLeft(2, '0')}-'
                '${key.day.toString().padLeft(2, '0')}': [
              value.up,
              value.down,
            ],
        }),
      );
}
