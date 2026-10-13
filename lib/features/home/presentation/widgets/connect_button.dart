import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branding/animated_phoenix.dart';
import '../../../../core/branding/phoenix.dart';
import '../../../../core/theme/glass.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../connection/domain/vpn_state.dart';
import '../../../profiles/application/profiles_controller.dart';
import '../../../profiles/presentation/import_actions.dart';

Color statusColor(BuildContext context, VpnStatus status) {
  final colors = StatusColors.of(context);
  return switch (status) {
    VpnStatus.connected => colors.connected,
    VpnStatus.connecting || VpnStatus.disconnecting => colors.connecting,
    VpnStatus.disconnected => colors.disconnected,
  };
}

/// The connect button: a glass orb holding the phoenix. The bird is ash
/// while disconnected, catches fire as the tunnel comes up, and a flame
/// circles the orb while connecting.
class ConnectButton extends ConsumerStatefulWidget {
  const ConnectButton({super.key, this.size = 210});

  final double size;

  @override
  ConsumerState<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<ConnectButton>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  // Drives the wing flap: a loop while connecting, then a short settling
  // burst once connected that ends on fully open wings.
  late final AnimationController _flap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  VpnStatus? _lastStatus;
  bool _pressed = false;

  @override
  void dispose() {
    _spin.dispose();
    _flap.dispose();
    super.dispose();
  }

  /// Starts the right wing motion when the connection state changes: a loop
  /// while busy, a one-off welcome flap on connect, held still when off. Kept
  /// finite when connected so widget tests still settle.
  void _onStatus(VpnStatus status) {
    if (status == _lastStatus) return;
    _lastStatus = status;
    switch (status) {
      case VpnStatus.connecting || VpnStatus.disconnecting:
        _flap.repeat(period: const Duration(milliseconds: 520));
      case VpnStatus.connected:
        _flap.forward(from: 0);
      case VpnStatus.disconnected:
        _flap.stop();
    }
  }

  /// The extra wing swing, in degrees, for the current frame.
  double _flapDegrees(VpnStatus status) {
    final v = _flap.value;
    return switch (status) {
      VpnStatus.connecting || VpnStatus.disconnecting =>
        13 * math.sin(v * 2 * math.pi),
      // A few flaps on arrival, damped so the wings settle fully open.
      VpnStatus.connected => 11 * math.sin(v * 2 * math.pi * 3) * (1 - v) * (1 - v),
      VpnStatus.disconnected => 0,
    };
  }

  Future<void> _onTap() async {
    final profiles = ref.read(profilesProvider).value;
    final disconnected =
        ref.read(vpnControllerProvider).status == VpnStatus.disconnected;
    if (!(profiles?.hasSelection ?? false) && disconnected) {
      context.showSnack(context.l10n.selectConfigFirst);
      return;
    }
    // An OpenVPN or Cisco server needs its login before it can connect.
    final selected = profiles?.selected;
    if (disconnected && selected != null && selected.config.needsLogin) {
      await ImportActions(context, ref).login(selected);
      final updated = ref.read(selectedProfileProvider);
      if (updated == null || updated.config.needsLogin) return;
    }
    await ref.read(vpnControllerProvider.notifier).toggle();
  }

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vpnControllerProvider.select((s) => s.status));
    final busy =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;
    if (busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!busy && _spin.isAnimating) {
      _spin.stop();
    }

    final connected = status == VpnStatus.connected;
    final fire = StatusColors.of(context).connected;
    final ember = GlassStyle.of(context).ember;
    final ash = context.colors.onSurfaceVariant.withValues(alpha: 0.65);
    final l10n = context.l10n;
    final size = widget.size;

    // Wings: tucked when off, part-open and beating while connecting, flung
    // fully open on connect.
    _onStatus(status);
    final targetSpread = connected
        ? 1.0
        : busy
        ? 0.9
        : 0.0;

    return Semantics(
      button: true,
      label: connected ? l10n.disconnect : l10n.connect,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: status == VpnStatus.disconnecting ? null : _onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              end: connected
                  ? 1
                  : busy
                  ? 0.45
                  : 0,
            ),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, heat, _) => SizedBox.square(
              dimension: size * 1.3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (heat > 0)
                    Container(
                      width: size * 1.3,
                      height: size * 1.3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            ember.withValues(alpha: 0.5 * heat),
                            ember.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  if (busy)
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => CustomPaint(
                        size: Size.square(size + 20),
                        painter: _FlameArcPainter(_spin.value),
                      ),
                    ),
                  SizedBox.square(
                    dimension: size,
                    child: Glass(
                      circle: true,
                      shadow: true,
                      tint: heat > 0 ? fire : null,
                      tintStrength: 0.2 * heat,
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: targetSpread),
                          duration: const Duration(milliseconds: 820),
                          curve: Curves.easeOutCubic,
                          builder: (context, spread, _) => AnimatedBuilder(
                            animation: _flap,
                            builder: (context, _) => AnimatedPhoenix(
                              size: size * 0.74,
                              spread: spread,
                              flapDegrees: _flapDegrees(status),
                              heat: heat,
                              ash: ash,
                              glow: heat * 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A comet of fire circling the orb.
class _FlameArcPainter extends CustomPainter {
  _FlameArcPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final start = t * 2 * math.pi;
    const sweep = math.pi * 0.9;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: [
            phoenixFire.last.withValues(alpha: 0),
            phoenixFire[1],
            phoenixFire.first,
          ],
          transform: GradientRotation(start),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FlameArcPainter old) => old.t != t;
}
