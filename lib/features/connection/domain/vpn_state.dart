import '../../../core/singbox/builder/core_options.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting }

enum VpnErrorCode {
  permissionDenied,
  adminRequired,
  coreMissing,
  coreExited,
  unsupportedPlatform,
  invalidConfig,

  /// Auto mode found no server that answers.
  noWorkingServer,
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
    this.autoProfileIds = const [],
    this.findingServer = false,
  });

  final VpnStatus status;
  final VpnError? error;
  final DateTime? connectedSince;
  final String? profileId;

  /// Clash API endpoint of the running core, used for live statistics.
  final ClashApiOptions? clashApi;

  /// Auto mode: the candidate profiles in the order of their core tags
  /// (`auto-0`, `auto-1`, …). Empty for a single selected server.
  final List<String> autoProfileIds;

  /// Auto mode is measuring servers before the core starts.
  final bool findingServer;

  bool get isAuto => autoProfileIds.isNotEmpty;

  bool get isBusy =>
      status == VpnStatus.connecting || status == VpnStatus.disconnecting;

  bool get isConnected => status == VpnStatus.connected;

  VpnState copyWith({
    VpnStatus? status,
    VpnError? Function()? error,
    DateTime? Function()? connectedSince,
    String? Function()? profileId,
    ClashApiOptions? Function()? clashApi,
    List<String>? autoProfileIds,
    bool? findingServer,
  }) => VpnState(
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    connectedSince: connectedSince != null
        ? connectedSince()
        : this.connectedSince,
    profileId: profileId != null ? profileId() : this.profileId,
    clashApi: clashApi != null ? clashApi() : this.clashApi,
    autoProfileIds: autoProfileIds ?? this.autoProfileIds,
    findingServer: findingServer ?? this.findingServer,
  );
}
