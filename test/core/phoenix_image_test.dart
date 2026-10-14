import 'package:aghelan_ghiamat/core/branding/phoenix_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds off and lit without error, keeps its size', (
    tester,
  ) async {
    for (final heat in [0.0, 1.0]) {
      await tester.pumpWidget(
        Center(child: PhoenixImageMark(size: 120, heat: heat, glow: heat * 0.4)),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(PhoenixImageMark)),
        const Size.square(120),
      );
      // The artwork is desaturated/relit through a colour filter.
      expect(
        find.descendant(
          of: find.byType(PhoenixImageMark),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
    }
  });
}
