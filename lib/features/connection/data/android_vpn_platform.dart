import 'package:flutter/services.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../domain/vpn_state.dart';
import '../../logs/domain/core_log_line.dart';
import 'clash_api_client.dart';
import 'vpn_platform.dart';

/// Talks to `VpnBridge.kt`, which runs sing-box through libbox inside an
/// Android `VpnService`.
class AndroidVpnPlatform implements VpnPlatform {
  AndroidVpnPlatform({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('com.aghelan.ghiamat/vpn'),
      _eventChannel =
          events ?? const EventChannel('com.aghelan.ghiamat/vpn_events');

  final MethodChannel _methods;
  final EventChannel _eventChannel;

  @override
  CorePlatform get corePlatform => CorePlatform.android;

  @override
  late final Stream<VpnPlatformEvent> events = _eventChannel
      .receiveBroadcastStream()
      .map(parseEvent)
      .where((e) => e != null)
      .cast<VpnPlatformEvent>();

  /// Maps `{"status": "...", "error": "..."}` maps sent by the service.
  static VpnPlatformEvent? parseEvent(Object? raw) {
    if (raw is! Map) return null;
    final error = raw['error'] as String?;
    return switch (raw['status']) {
      'started' => const VpnStarted(),
      'stopped' => VpnStopped(
        error == null || error.isEmpty
            ? null
            : VpnError(VpnErrorCode.coreExited, error),
      ),
      'log' => VpnLogLine(raw['message'] as String? ?? ''),
      _ => null,
    };
  }

  @override
  Future<String?> workingDirectory() =>
      _methods.invokeMethod<String>('workingDirectory');

  @override
  Future<void> start(VpnStartRequest request) async {
    try {
      await _methods.invokeMethod<void>('start', {
        'config': request.configJson,
        'name': request.profileName,
      });
    } on PlatformException catch (e) {
      throw VpnError(switch (e.code) {
        'PERMISSION_DENIED' => VpnErrorCode.permissionDenied,
        'INVALID_CONFIG' => VpnErrorCode.invalidConfig,
        _ => VpnErrorCode.unknown,
      }, e.message);
    }
  }

  @override
  Future<void> stop() => _methods.invokeMethod<void>('stop');

  @override
  Future<bool> isRunning() async =>
      await _methods.invokeMethod<bool>('isRunning') ?? false;

  @override
  Future<String?> coreVersion() => _methods.invokeMethod<String>('coreVersion');

  @override
  Future<String?> checkConfig(String configJson) =>
      _methods.invokeMethod<String>('checkConfig', {'config': configJson});

  /// The tester runs as a second libbox instance inside the app process;
  /// its sockets are protected from the VPN tunnel by the VpnService.
  @override
  Future<void> startTester(String configJson) async {
    try {
      await _methods.invokeMethod<void>('startTester', {'config': configJson});
    } on PlatformException catch (e) {
      throw VpnError(VpnErrorCode.coreExited, e.message);
    }
    final api = ClashApiClient.optionsFromConfig(configJson);
    if (api == null) return;
    final client = ClashApiClient(api);
    for (var i = 0; i < 25; i++) {
      if (await client.ping()) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await stopTester();
    throw const VpnError(VpnErrorCode.coreExited, 'tester did not start');
  }

  @override
  Future<void> stopTester() => _methods.invokeMethod<void>('stopTester');

  @override
  Stream<CoreLogLine> coreLogs() =>
      const EventChannel('com.aghelan.ghiamat/logs')
          .receiveBroadcastStream()
          .map((raw) {
            final entry = raw as Map;
            return CoreLogLine.leveled(
              entry['level'] as int? ?? LogLevel.info.index,
              entry['message'] as String? ?? '',
            );
          });
}
