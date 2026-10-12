import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branding/phoenix.dart';
import '../../../../core/theme/glass.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../connection/application/vpn_controller.dart';
import '../../../connection/domain/vpn_state.dart';
import '../../../profiles/application/profiles_controller.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _onTap() {
    final hasSelection =
        ref.read(profilesProvider).value?.hasSelection ?? false;
    if (!hasSelection &&
        ref.read(vpnControllerProvider).status == VpnStatus.disconnected) {
      context.showSnack(context.l10n.selectConfigFirst);
      return;
    }
    ref.read(vpnControllerProvider.notifier).toggle();
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
                        child: PhoenixMark(
                          size: size * 0.68,
                          heat: heat,
                          ash: ash,
                          glow: heat * 0.6,
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
