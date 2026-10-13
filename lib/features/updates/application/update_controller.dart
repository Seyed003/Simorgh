import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/storage/preferences.dart';
import '../data/update_checker.dart';

/// The newer release, if one was found and not dismissed.
class UpdateState {
  const UpdateState({this.available, this.checking = false});

  final AppRelease? available;
  final bool checking;
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);

class UpdateController extends Notifier<UpdateState> {
  static const _lastCheckKey = 'update.last_check';
  static const _dismissedKey = 'update.dismissed';
  static const interval = Duration(hours: 24);

  @override
  UpdateState build() => const UpdateState();

  /// Once a day at most, quietly.
  Future<void> checkAutomatically({DateTime? now}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final at = now ?? DateTime.now();
    final last = prefs.getInt(_lastCheckKey);
    if (last != null &&
        at.difference(DateTime.fromMillisecondsSinceEpoch(last)) < interval) {
      return;
    }
    try {
      await check(now: at);
    } on Object {
      // Offline or blocked; try again next time.
    }
  }

  /// Returns the newer release, or `null` when this is the latest. Throws
  /// when the check fails.
  Future<AppRelease?> check({DateTime? now}) async {
    state = UpdateState(available: state.available, checking: true);
    try {
      final release = await ref.read(updateCheckerProvider).latest();
      await ref
          .read(sharedPreferencesProvider)
          .setInt(
            _lastCheckKey,
            (now ?? DateTime.now()).millisecondsSinceEpoch,
          );
      final newer =
          release != null &&
              compareVersions(release.version, AppInfo.version) > 0
          ? release
          : null;
      final dismissed = ref
          .read(sharedPreferencesProvider)
          .getString(_dismissedKey);
      state = UpdateState(
        available: newer != null && newer.version != dismissed ? newer : null,
      );
      return newer;
    } on Object {
      state = UpdateState(available: state.available);
      rethrow;
    }
  }

  /// Hides the banner until a newer version than this one appears.
  Future<void> dismiss() async {
    final release = state.available;
    if (release == null) return;
    state = const UpdateState();
    await ref
        .read(sharedPreferencesProvider)
        .setString(_dismissedKey, release.version);
  }
}
