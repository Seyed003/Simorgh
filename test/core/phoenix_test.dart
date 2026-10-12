import 'package:aghelan_ghiamat/core/branding/phoenix.dart';
import 'package:aghelan_ghiamat/core/branding/phoenix_paths.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every brand path parses and stays on the 512 canvas', () {
    const canvas = Rect.fromLTWH(0, 0, 512, 512);
    for (final d in phoenixPaths) {
      final bounds = parseSvgPath(d).getBounds();
      expect(bounds.isEmpty, isFalse, reason: d);
      expect(canvas.contains(bounds.topLeft), isTrue, reason: d);
      expect(canvas.contains(bounds.bottomRight), isTrue, reason: d);
    }
    // The ring hangs below its gap at the top.
    final ring = parseSvgPath(phoenixRingPath);
    expect(ring.contains(const Offset(256, 400)), isTrue);
    expect(ring.getBounds().top, closeTo(162, 0.5));
  });

  test('parses lines, curves, arcs and implicit line-tos', () {
    final path = parseSvgPath('M10,10 20,10 L20,20 C25,25 30,25 35,20 Z');
    expect(path.getBounds().left, 10);
    expect(path.getBounds().right, 35);
    expect(
      parseSvgPath('M0,50 A50,50 0 1,0 100,50').getBounds().height,
      closeTo(50, 0.5),
    );
    expect(() => parseSvgPath('M0,0 Q1,1 2,2'), throwsFormatException);
  });

  testWidgets('heat blends from ash to fire', (tester) async {
    await tester.pumpWidget(
      const Center(child: PhoenixMark(size: 64, heat: 0.5)),
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(PhoenixMark),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as PhoenixPainter;
    expect(painter.heat, 0.5);
    expect(painter.shouldRepaint(PhoenixPainter(heat: 1)), isTrue);
    expect(tester.getSize(find.byType(PhoenixMark)), const Size.square(64));
  });
}
