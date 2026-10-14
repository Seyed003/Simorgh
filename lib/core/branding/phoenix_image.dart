import 'package:flutter/widgets.dart';

/// The phoenix artwork on the connect button: ash grey and dim while the VPN
/// is off, catching full colour with a warm glow as the tunnel comes up.
///
/// [heat] 0 draws it desaturated and dim, 1 at full fire; [glow] is the
/// strength of the ember halo behind it.
class PhoenixImageMark extends StatelessWidget {
  const PhoenixImageMark({
    super.key,
    this.size = 150,
    this.heat = 1,
    this.glow = 0,
  });

  final double size;
  final double heat;
  final double glow;

  /// A saturation + brightness colour matrix: [s] 0 greys the image out, 1
  /// leaves it untouched; every channel is then scaled by [b].
  static List<double> _matrix(double s, double b) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final a = 1 - s;
    return <double>[
      (lr * a + s) * b, lg * a * b, lb * a * b, 0, 0, //
      lr * a * b, (lg * a + s) * b, lb * a * b, 0, 0, //
      lr * a * b, lg * a * b, (lb * a + s) * b, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF8A2B).withValues(alpha: 0.5 * glow),
                    const Color(0x00FF8A2B),
                  ],
                ),
              ),
              child: SizedBox.square(dimension: size),
            ),
          Transform.scale(
            scale: 0.94 + 0.06 * heat,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(
                _matrix(heat, 0.6 + 0.4 * heat),
              ),
              child: Image.asset(
                'assets/branding/phoenix_mark.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
