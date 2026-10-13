import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/network/domain/network_identity.dart';

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

  /// Opens [url] in the browser.
  Future<void> openUrl(String url) async {
    if (_android) {
      await _methods.invokeMethod<void>('openUrl', {'url': url});
    } else if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    }
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

  /// The network under the VPN; a desktop counts as one network.
  Future<NetworkIdentity> network() async {
    if (!_android) return NetworkIdentity.desktop;
    final raw = await _methods.invokeMapMethod<String, Object?>('networkInfo');
    return raw == null
        ? const NetworkIdentity(kind: NetworkKind.other)
        : NetworkIdentity.fromMap(raw);
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
