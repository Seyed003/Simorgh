import 'dart:io';

import 'android_vpn_platform.dart';
import 'vpn_platform.dart';
import 'windows_vpn_platform.dart';

/// Picks the VPN implementation for the running OS.
VpnPlatform createVpnPlatform() {
  if (Platform.isAndroid) return AndroidVpnPlatform();
  if (Platform.isWindows) return WindowsVpnPlatform();
  return const UnsupportedVpnPlatform();
}
