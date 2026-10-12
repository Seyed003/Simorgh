import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'phoenix_paths.g.dart';

/// Brand fire gradient, top to bottom: gold, orange, crimson.
const phoenixFire = [Color(0xFFFFE08A), Color(0xFFFF8A2B), Color(0xFFE5305B)];

/// The phoenix mark (see scripts/make_brand.py), drawn from its path data.
class PhoenixMark extends StatelessWidget {
  const PhoenixMark({
    super.key,
    this.size = 96,
    this.heat = 1,
    this.ash,
    this.color,
    this.ring = false,
    this.ringColor,
    this.glow = 0,
  });

  final double size;

  /// 0 draws the bird in [ash], 1 in full fire; values between blend.
  final double heat;
  final Color? ash;

  /// Solid colour instead of the fire gradient.
  final Color? color;
  final bool ring;
  final Color? ringColor;

  /// 0..1: strength of the fire glow behind the bird.
  final double glow;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: PhoenixPainter(
        heat: heat,
        ash: ash ?? const Color(0xFF9AA3B2),
        color: color,
        ring: ring,
        ringColor: ringColor,
        glow: glow,
      ),
    ),
  );
}

class PhoenixPainter extends CustomPainter {
  PhoenixPainter({
    this.heat = 1,
    this.ash = const Color(0xFF9AA3B2),
    this.color,
    this.ring = false,
    this.ringColor,
    this.glow = 0,
  });

  final double heat;
  final Color ash;
  final Color? color;
  final bool ring;
  final Color? ringColor;
  final double glow;

  static final Path _bird = phoenixPaths.fold(
    Path(),
    (all, d) => all..addPath(parseSvgPath(d), Offset.zero),
  );
  static final Path _ring = parseSvgPath(phoenixRingPath);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 512;
    canvas
      ..save()
      ..scale(scale);
    if (glow > 0) {
      canvas.drawCircle(
        const Offset(256, 270),
        250,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(256, 270), 250, [
            const Color(0xFFFF8A2B).withValues(alpha: 0.55 * glow),
            const Color(0x00FF8A2B),
          ]),
      );
    }
    if (ring) {
      canvas.drawPath(
        _ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = ringColor ?? const Color(0x66FFFFFF),
      );
    }
    final paint = Paint()..isAntiAlias = true;
    if (color case final color?) {
      paint.color = color;
    } else {
      paint.shader = ui.Gradient.linear(
        const Offset(0, 40),
        const Offset(0, 490),
        [for (final c in phoenixFire) Color.lerp(ash, c, heat)!],
        const [0, 0.5, 1],
      );
    }
    canvas
      ..drawPath(_bird, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(PhoenixPainter old) =>
      old.heat != heat ||
      old.ash != ash ||
      old.color != color ||
      old.ring != ring ||
      old.ringColor != ringColor ||
      old.glow != glow;
}

/// Parses the subset of SVG path data the brand generator writes: absolute
/// M, L, C, A and Z.
Path parseSvgPath(String data) {
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+(?:e-?\d+)?')
      .allMatches(data)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  String? command;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final token = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(token)) {
      command = token;
      i++;
      if (command == 'Z') path.close();
      continue;
    }
    switch (command) {
      case 'M':
        path.moveTo(next(), next());
        command = 'L'; // Further pairs are implicit line-tos.
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'A':
        final rx = next();
        final ry = next();
        final rotation = next();
        final largeArc = next() != 0;
        final sweep = next() != 0;
        path.arcToPoint(
          Offset(next(), next()),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
      default:
        throw FormatException('unsupported path data', data);
    }
  }
  return path;
}
