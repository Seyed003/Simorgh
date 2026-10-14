import 'package:aghelan_ghiamat/core/branding/animated_phoenix.dart';
import 'package:aghelan_ghiamat/core/branding/phoenix.dart';
import 'package:aghelan_ghiamat/core/branding/phoenix_anim.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('body paths parse and stay on the 512 canvas', () {
    const canvas = Rect.fromLTWH(0, 0, 512, 512);
    for (final d in phoenixBodyPaths) {
      final bounds = parseSvgPath(d).getBounds();
      expect(bounds.isEmpty, isFalse, reason: d);
      expect(canvas.contains(bounds.topLeft), isTrue, reason: d);
      expect(canvas.contains(bounds.bottomRight), isTrue, reason: d);
    }
  });

  test('wing paths parse and are local (around the shoulder origin)', () {
    expect(phoenixWingPaths, isNotEmpty);
    for (final d in phoenixWingPaths) {
      final bounds = parseSvgPath(d).getBounds();
      expect(bounds.isEmpty, isFalse, reason: d);
      // Local coordinates: the shoulder sits at the origin, so the wing
      // reaches into negative x/y, unlike the absolute body.
      expect(bounds.left, lessThan(60), reason: d);
    }
  });

  test('fold constants are sane', () {
    expect(phoenixFoldScale, greaterThan(0));
    expect(phoenixFoldScale, lessThan(1));
    expect(phoenixFoldDegrees, greaterThan(0));
    expect(phoenixPivotX, lessThan(phoenixCenterX));
  });

  test('painter repaints when its drive values change', () {
    AnimatedPhoenixPainter p(double spread, double flap, double heat) =>
        AnimatedPhoenixPainter(
          spread: spread,
          flapDegrees: flap,
          heat: heat,
          ash: const Color(0xFF9AA3B2),
          glow: 0,
        );
    final base = p(1, 0, 1);
    expect(base.shouldRepaint(p(0, 0, 1)), isTrue);
    expect(base.shouldRepaint(p(1, 8, 1)), isTrue);
    expect(base.shouldRepaint(p(1, 0, 0)), isTrue);
    expect(base.shouldRepaint(p(1, 0, 1)), isFalse);
  });

  testWidgets('builds folded and open without error', (tester) async {
    for (final spread in [0.0, 1.0]) {
      await tester.pumpWidget(
        Center(child: AnimatedPhoenix(size: 120, spread: spread)),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AnimatedPhoenix)),
        const Size.square(120),
      );
    }
  });
}
