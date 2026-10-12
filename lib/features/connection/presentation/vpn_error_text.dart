import 'package:flutter/widgets.dart';

import '../../../core/utils/context_ext.dart';
import '../domain/vpn_state.dart';

String vpnErrorText(BuildContext context, VpnError error) {
  final l10n = context.l10n;
  final message = error.message ?? '';
  return switch (error.code) {
    VpnErrorCode.permissionDenied => l10n.errorVpnPermissionDenied,
    VpnErrorCode.adminRequired => l10n.errorAdminRequired,
    VpnErrorCode.coreMissing => l10n.errorCoreMissing,
    VpnErrorCode.coreExited => l10n.errorCoreExited(message),
    VpnErrorCode.unsupportedPlatform => l10n.errorUnsupportedPlatform,
    VpnErrorCode.invalidConfig =>
      message.isEmpty
          ? l10n.selectConfigFirst
          : l10n.errorInvalidConfig(message),
    VpnErrorCode.unknown => l10n.errorUnknown(message),
  };
}
