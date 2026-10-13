import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/net_utils.dart';

final coreOptionsProvider =
    NotifierProvider<CoreOptionsController, CoreOptions>(
      CoreOptionsController.new,
    );

/// Platform defaults: Windows exposes a local HTTP/SOCKS proxy for apps that
/// do not go through TUN; Android keeps localhost closed by default because
/// some apps probe local ports to detect VPN usage.
CoreOptions defaultCoreOptions() => Platform.isWindows
    ? const CoreOptions(mixedPort: 2080)
    : const CoreOptions();

class CoreOptionsController extends Notifier<CoreOptions> {
  static const _key = 'settings.core';

  @override
  CoreOptions build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final options = _load(prefs.getString(_key));
    final secured = _withPassword(options);
    if (!identical(secured, options)) {
      unawaited(prefs.setString(_key, jsonEncode(secured.toJson())));
    }
    return secured;
  }

  /// A local proxy that should ask for a password but has none (the
  /// Windows default, older settings, a restored backup) gets one: an open
  /// proxy lets any program on the computer use the VPN.
  static CoreOptions _withPassword(CoreOptions options) =>
      options.mixedPort != null &&
          options.mixedAuth &&
          (options.mixedPassword ?? '').isEmpty
      ? options.copyWith(mixedPassword: randomHexSecret(8))
      : options;

  CoreOptions _load(String? raw) {
    final defaults = defaultCoreOptions();
    if (raw == null) return defaults;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return CoreOptions.fromJson(
          json.cast<String, Object?>(),
          defaults: defaults,
        );
      }
    } on FormatException {
      // Fall back to defaults on a corrupted value.
    }
    return defaults;
  }

  Future<void> update(CoreOptions Function(CoreOptions current) change) async {
    state = _withPassword(change(state));
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final defaults = defaultCoreOptions();
    state = _withPassword(defaults);
    // Stored only to keep a new proxy password across restarts.
    if (identical(state, defaults)) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(state.toJson()));
    }
  }
}
