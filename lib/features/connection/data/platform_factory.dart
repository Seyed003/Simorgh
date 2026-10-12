import 'vpn_platform.dart';

/// Picks the VPN implementation for the running OS.
VpnPlatform createVpnPlatform() => const UnsupportedVpnPlatform();
