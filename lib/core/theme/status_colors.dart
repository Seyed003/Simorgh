import 'package:flutter/material.dart';

/// Semantic colors for the connection state, exposed as a [ThemeExtension]
/// so both light and dark themes can tune them independently.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.connected,
    required this.connecting,
    required this.disconnected,
    required this.error,
  });

  final Color connected;
  final Color connecting;
  final Color disconnected;
  final Color error;

  static const light = StatusColors(
    connected: Color(0xFF16A34A),
    connecting: Color(0xFFD97706),
    disconnected: Color(0xFF64748B),
    error: Color(0xFFDC2626),
  );

  static const dark = StatusColors(
    connected: Color(0xFF4ADE80),
    connecting: Color(0xFFFBBF24),
    disconnected: Color(0xFF94A3B8),
    error: Color(0xFFF87171),
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

  @override
  StatusColors copyWith({
    Color? connected,
    Color? connecting,
    Color? disconnected,
    Color? error,
  }) {
    return StatusColors(
      connected: connected ?? this.connected,
      connecting: connecting ?? this.connecting,
      disconnected: disconnected ?? this.disconnected,
      error: error ?? this.error,
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
    );
  }
}
