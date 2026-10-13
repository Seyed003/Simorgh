import '../../../core/singbox/builder/core_options.dart';
import '../../logs/domain/core_log_line.dart';
import '../domain/vpn_state.dart';

/// Events pushed by the native VPN service (Android) or the core process
/// (Windows).
sealed class VpnPlatformEvent {
  const VpnPlatformEvent();
}

class VpnStarted extends VpnPlatformEvent {
  const VpnStarted();
}

class VpnStopped extends VpnPlatformEvent {
  const VpnStopped([this.error]);

  final VpnError? error;
}

class VpnLogLine extends VpnPlatformEvent {
  const VpnLogLine(this.line);

  final String line;
}

class VpnStartRequest {
  const VpnStartRequest({required this.configJson, required this.profileName});

  /// Complete sing-box configuration.
  final String configJson;

  /// Shown in the Android notification / Windows tray tooltip.
  final String profileName;
}

/// Platform specific way of running sing-box with a TUN device.
abstract class VpnPlatform {
  CorePlatform get corePlatform;

  /// Directory the core uses for `cache.db` and logs, if any.
  Future<String?> workingDirectory();

  Stream<VpnPlatformEvent> get events;

  /// Starts the core. Completes once the start has been *requested*; the
  /// outcome arrives through [events].
  Future<void> start(VpnStartRequest request);

  Future<void> stop();

  /// Status of a service that may still be running from a previous app
  /// session (Android keeps the VpnService alive when the UI is closed).
  Future<bool> isRunning();

  Future<String?> coreVersion();

  /// Validates [configJson] with the core. Returns the core's error message,
  /// or `null` when the config is valid.
  Future<String?> checkConfig(String configJson);

  /// Starts a secondary core used only for latency tests: no TUN, its
  /// sockets bypass a running tunnel. Completes once its Clash API answers;
  /// throws a [VpnError] when it cannot start.
  Future<void> startTester(String configJson);

  Future<void> stopTester();

  /// The running core's log: recent lines first, then new ones.
  Stream<CoreLogLine> coreLogs();
}

/// Used on platforms without a VPN implementation and in tests.
class UnsupportedVpnPlatform implements VpnPlatform {
  const UnsupportedVpnPlatform();

  @override
  CorePlatform get corePlatform => CorePlatform.other;

  @override
  Stream<VpnPlatformEvent> get events => const Stream.empty();

  @override
  Future<String?> workingDirectory() async => null;

  @override
  Future<void> start(VpnStartRequest request) async =>
      throw const VpnError(VpnErrorCode.unsupportedPlatform);

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;

  @override
  Future<String?> coreVersion() async => null;

  @override
  Future<String?> checkConfig(String configJson) async => null;

  @override
  Future<void> startTester(String configJson) async =>
      throw const VpnError(VpnErrorCode.unsupportedPlatform);

  @override
  Future<void> stopTester() async {}

  @override
  Stream<CoreLogLine> coreLogs() => const Stream.empty();
}
