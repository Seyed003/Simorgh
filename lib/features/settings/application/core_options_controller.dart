import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/storage/preferences.dart';

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
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
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
    state = change(state);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> reset() async {
    state = defaultCoreOptions();
    await ref.read(sharedPreferencesProvider).remove(_key);
  }
}
