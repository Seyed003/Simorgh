import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'phoenix.dart' show phoenixFire, parseSvgPath;
import 'phoenix_anim.g.dart';

/// The connect-button phoenix, drawn from path data so its wings can move:
/// folded while the VPN is off, spreading open and flapping as it connects.
///
/// [spread] 0 keeps the wings tucked, 1 opens them fully; [flapDegrees] is an
/// extra swing added on top for the flap. [heat] blends the fire gradient in
/// from [ash] (0 = ash, 1 = full fire).
class AnimatedPhoenix extends StatelessWidget {
  const AnimatedPhoenix({
    super.key,
    this.size = 140,
    this.spread = 1,
    this.flapDegrees = 0,
    this.heat = 1,
    this.ash = const Color(0xFF9AA3B2),
    this.glow = 0,
  });

  final double size;
  final double spread;
  final double flapDegrees;
  final double heat;
  final Color ash;
  final double glow;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: AnimatedPhoenixPainter(
        spread: spread,
        flapDegrees: flapDegrees,
        heat: heat,
        ash: ash,
        glow: glow,
      ),
    ),
  );
}

class AnimatedPhoenixPainter extends CustomPainter {
  AnimatedPhoenixPainter({
    required this.spread,
    required this.flapDegrees,
    required this.heat,
    required this.ash,
    required this.glow,
  });

  final double spread;
  final double flapDegrees;
  final double heat;
  final Color ash;
  final double glow;

  static final List<Path> _wing = phoenixWingPaths.map(parseSvgPath).toList();
  static final List<Path> _body = phoenixBodyPaths.map(parseSvgPath).toList();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 512;
    canvas
      ..save()
      ..scale(scale);
    if (glow > 0) {
      canvas.drawCircle(
        const Offset(256, 262),
        250,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(256, 262), 250, [
            const Color(0xFFFF8A2B).withValues(alpha: 0.55 * glow),
            const Color(0x00FF8A2B),
          ]),
      );
    }
    final angle =
        ((1 - spread) * phoenixFoldDegrees + flapDegrees) * math.pi / 180;
    final wingScale = phoenixFoldScale + (1 - phoenixFoldScale) * spread;
    final wingScaleM = Matrix4.diagonal3Values(wingScale, wingScale, 1);
    final spin = Matrix4.rotationZ(angle);
    final right = Matrix4.translationValues(phoenixPivotX, phoenixPivotY, 0)
        .multiplied(spin)
        .multiplied(wingScaleM);
    final left = Matrix4.translationValues(
      2 * phoenixCenterX - phoenixPivotX,
      phoenixPivotY,
      0,
    ).multiplied(Matrix4.diagonal3Values(-1, 1, 1)).multiplied(spin).multiplied(wingScaleM);

    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        const Offset(0, 60),
        const Offset(0, 470),
        [for (final c in phoenixFire) Color.lerp(ash, c, heat)!],
        const [0, 0.5, 1],
      );
    // Each feather is drawn on its own so overlaps union (a single merged
    // path would cancel where feather windings oppose). Wings first, then
    // the body over them so it hides the roots.
    for (final w in _wing) {
      canvas
        ..drawPath(w.transform(left.storage), paint)
        ..drawPath(w.transform(right.storage), paint);
    }
    for (final b in _body) {
      canvas.drawPath(b, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnimatedPhoenixPainter old) =>
      old.spread != spread ||
      old.flapDegrees != flapDegrees ||
      old.heat != heat ||
      old.ash != ash ||
      old.glow != glow;
}
