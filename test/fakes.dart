import 'dart:async';

import 'package:aghelan_ghiamat/core/singbox/builder/core_options.dart';
import 'package:aghelan_ghiamat/features/connection/data/vpn_platform.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';

/// In-memory VPN platform that records requests and lets tests drive the
/// native side's events.
class FakeVpnPlatform implements VpnPlatform {
  FakeVpnPlatform({
    this.autoStart = true,
    this.startError,
    this.running = false,
  });

  /// Emit [VpnStarted] right after [start].
  final bool autoStart;
  final VpnError? startError;
  bool running;

  final _events = StreamController<VpnPlatformEvent>.broadcast();
  final requests = <VpnStartRequest>[];
  int stopCalls = 0;

  void emit(VpnPlatformEvent event) => _events.add(event);

  @override
  CorePlatform get corePlatform => CorePlatform.android;

  @override
  Stream<VpnPlatformEvent> get events => _events.stream;

  @override
  Future<String?> workingDirectory() async => null;

  @override
  Future<void> start(VpnStartRequest request) async {
    if (startError != null) throw startError!;
    requests.add(request);
    running = true;
    if (autoStart) scheduleMicrotask(() => emit(const VpnStarted()));
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    running = false;
    scheduleMicrotask(() => emit(const VpnStopped()));
  }

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<String?> coreVersion() async => '1.14.3';

  /// Errors returned by [checkConfig], consumed one per call.
  final checkErrors = <String>[];
  final checkedConfigs = <String>[];
  final testerConfigs = <String>[];
  int stopTesterCalls = 0;

  @override
  Future<String?> checkConfig(String configJson) async {
    checkedConfigs.add(configJson);
    return checkErrors.isEmpty ? null : checkErrors.removeAt(0);
  }

  @override
  Future<void> startTester(String configJson) async =>
      testerConfigs.add(configJson);

  @override
  Future<void> stopTester() async => stopTesterCalls++;
}
