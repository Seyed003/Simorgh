import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android system integration (see SystemBridge.kt); no-ops elsewhere.
class SystemBridge {
  const SystemBridge();

  static const _methods = MethodChannel('com.aghelan.ghiamat/system');
  static const _shared = EventChannel('com.aghelan.ghiamat/shared');

  bool get _android => Platform.isAndroid;

  /// Android's VPN settings, where "Always-on VPN" and "Block connections
  /// without VPN" are switched on.
  Future<void> openVpnSettings() async {
    if (_android) await _methods.invokeMethod<void>('openVpnSettings');
  }

  /// Always-on / lockdown state of the running VPN; `null` when unknown
  /// (not connected, older Android, other platforms).
  Future<({bool alwaysOn, bool lockdown})?> vpnLockdown() async {
    if (!_android) return null;
    final raw = await _methods.invokeMapMethod<String, Object?>('vpnLockdown');
    if (raw == null) return null;
    return (
      alwaysOn: raw['alwaysOn'] == true,
      lockdown: raw['lockdown'] == true,
    );
  }

  /// Links and text other apps opened or shared the app with: first what
  /// arrived before anyone listened, then each new one.
  Stream<String> sharedText() async* {
    if (!_android) return;
    final pending = await _methods.invokeListMethod<String>('takeShared');
    yield* Stream.fromIterable(pending ?? const []);
    yield* _shared.receiveBroadcastStream().cast<String>();
  }
}

final systemBridgeProvider = Provider<SystemBridge>(
  (ref) => const SystemBridge(),
);
