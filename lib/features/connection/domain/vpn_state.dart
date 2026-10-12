import '../../../core/singbox/builder/core_options.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting }

enum VpnErrorCode {
  permissionDenied,
  adminRequired,
  coreMissing,
  coreExited,
  unsupportedPlatform,
  invalidConfig,
  unknown,
}

class VpnError implements Exception {
  const VpnError(this.code, [this.message]);

  final VpnErrorCode code;
  final String? message;

  @override
  String toString() =>
      'VpnError(${code.name}${message == null ? '' : ': $message'})';
}

class VpnState {
  const VpnState({
    this.status = VpnStatus.disconnected,
    this.error,
    this.connectedSince,
    this.profileId,
    this.clashApi,
  });

  final VpnStatus status;
  final VpnError? error;
  final DateTime? connectedSince;
  final String? profileId;

  /// Clash API endpoint of the running core, used for live statistics.
  final ClashApiOptions? clashApi;

  bool get isBusy =>
      status == VpnStatus.connecting || status == VpnStatus.disconnecting;

  bool get isConnected => status == VpnStatus.connected;

  VpnState copyWith({
    VpnStatus? status,
    VpnError? Function()? error,
    DateTime? Function()? connectedSince,
    String? Function()? profileId,
    ClashApiOptions? Function()? clashApi,
  }) => VpnState(
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    connectedSince: connectedSince != null
        ? connectedSince()
        : this.connectedSince,
    profileId: profileId != null ? profileId() : this.profileId,
    clashApi: clashApi != null ? clashApi() : this.clashApi,
  );
}
