import 'package:flutter/material.dart';

/// Semantic colors for the connection state, exposed as a [ThemeExtension]
/// so both light and dark themes can tune them independently.
///
/// Connected is the phoenix's fire; [good] (green) rates fast servers.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.connected,
    required this.connecting,
    required this.disconnected,
    required this.error,
    required this.good,
  });

  final Color connected;
  final Color connecting;
  final Color disconnected;
  final Color error;
  final Color good;

  static const light = StatusColors(
    connected: Color(0xFFC2410C),
    connecting: Color(0xFFB45309),
    disconnected: Color(0xFF64607A),
    error: Color(0xFFDC2626),
    good: Color(0xFF15803D),
  );

  static const dark = StatusColors(
    connected: Color(0xFFFF9A4D),
    connecting: Color(0xFFFFCF5C),
    disconnected: Color(0xFFA8A3C2),
    error: Color(0xFFFF7A8A),
    good: Color(0xFF5EE38F),
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

  @override
  StatusColors copyWith({
    Color? connected,
    Color? connecting,
    Color? disconnected,
    Color? error,
    Color? good,
  }) {
    return StatusColors(
      connected: connected ?? this.connected,
      connecting: connecting ?? this.connecting,
      disconnected: disconnected ?? this.disconnected,
      error: error ?? this.error,
      good: good ?? this.good,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      connected: Color.lerp(connected, other.connected, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      disconnected: Color.lerp(disconnected, other.disconnected, t)!,
      error: Color.lerp(error, other.error, t)!,
      good: Color.lerp(good, other.good, t)!,
    );
  }
}
