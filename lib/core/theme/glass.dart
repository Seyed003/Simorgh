import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colours of the "liquid glass" look: the aurora behind every screen and
/// the translucent panels floating over it.
@immutable
class GlassStyle extends ThemeExtension<GlassStyle> {
  const GlassStyle({
    required this.background,
    required this.blobs,
    required this.ember,
    required this.fill,
    required this.rim,
    required this.shadow,
    required this.blur,
  });

  /// Base gradient of the aurora, top to bottom.
  final List<Color> background;

  /// Soft colour clouds of the aurora.
  final List<Color> blobs;

  /// Fire glow that rises in the aurora while connected.
  final Color ember;

  /// Panel fill, top and bottom.
  final (Color, Color) fill;

  /// Rim light: bright edge and dim edge.
  final (Color, Color) rim;
  final Color shadow;
  final double blur;

  static const dark = GlassStyle(
    background: [Color(0xFF080A1A), Color(0xFF110D27), Color(0xFF190D24)],
    blobs: [Color(0x803346E8), Color(0x66A3237F), Color(0x4D1E7FD0)],
    ember: Color(0x99FF5F1F),
    fill: (Color(0x1FFFFFFF), Color(0x0AFFFFFF)),
    rim: (Color(0x73FFFFFF), Color(0x14FFFFFF)),
    shadow: Color(0x66000000),
    blur: 24,
  );

  static const light = GlassStyle(
    background: [Color(0xFFF6F3FB), Color(0xFFF0EBF8), Color(0xFFFBEEE8)],
    blobs: [Color(0x998FA4FF), Color(0x80FF9AC9), Color(0x6680D8FF)],
    ember: Color(0x99FF8A3D),
    fill: (Color(0xA6FFFFFF), Color(0x73FFFFFF)),
    rim: (Color(0xF2FFFFFF), Color(0x26FFFFFF)),
    shadow: Color(0x1F3B2A73),
    blur: 24,
  );

  static GlassStyle of(BuildContext context) =>
      Theme.of(context).extension<GlassStyle>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  GlassStyle copyWith({
    List<Color>? background,
    List<Color>? blobs,
    Color? ember,
    (Color, Color)? fill,
    (Color, Color)? rim,
    Color? shadow,
    double? blur,
  }) => GlassStyle(
    background: background ?? this.background,
    blobs: blobs ?? this.blobs,
    ember: ember ?? this.ember,
    fill: fill ?? this.fill,
    rim: rim ?? this.rim,
    shadow: shadow ?? this.shadow,
    blur: blur ?? this.blur,
  );

  @override
  GlassStyle lerp(ThemeExtension<GlassStyle>? other, double t) {
    if (other is! GlassStyle) return this;
    List<Color> list(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
    ];
    (Color, Color) pair((Color, Color) a, (Color, Color) b) =>
        (Color.lerp(a.$1, b.$1, t)!, Color.lerp(a.$2, b.$2, t)!);
    return GlassStyle(
      background: list(background, other.background),
      blobs: list(blobs, other.blobs),
      ember: Color.lerp(ember, other.ember, t)!,
      fill: pair(fill, other.fill),
      rim: pair(rim, other.rim),
      shadow: Color.lerp(shadow, other.shadow, t)!,
      blur: ui.lerpDouble(blur, other.blur, t)!,
    );
  }
}

/// A translucent panel: frosted backdrop, light fill, and a rim that is
/// bright on the lit edge and fades towards the other.
///
/// [blur] frosts what is behind the panel; it costs a backdrop pass, so long
/// lists use unblurred panels over the (already soft) aurora.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.circle = false,
    this.padding,
    this.blur = true,
    this.tint,
    this.tintStrength = 0.16,
    this.shadow = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final double radius;
  final bool circle;
  final EdgeInsetsGeometry? padding;
  final bool blur;

  /// Colours the fill and the rim, e.g. the selected server.
  final Color? tint;
  final double tintStrength;
  final bool shadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final style = GlassStyle.of(context);
    final shape = circle
        ? const CircleBorder()
        : RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          );
    var (top, bottom) = style.fill;
    var (lit, dim) = style.rim;
    final tint = this.tint;
    if (tint != null) {
      top = Color.alphaBlend(tint.withValues(alpha: tintStrength), top);
      bottom = Color.alphaBlend(
        tint.withValues(alpha: tintStrength * 0.7),
        bottom,
      );
      final mix = (tintStrength / 0.16).clamp(0.0, 1.0);
      lit = Color.lerp(lit, tint, 0.55 * mix)!;
      dim = Color.lerp(dim, tint.withValues(alpha: 0.35), 0.6 * mix)!;
    }

    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (onTap != null || onLongPress != null) {
      content = InkWell(
        customBorder: shape,
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }
    content = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
        ),
        child: content,
      ),
    );
    content = CustomPaint(
      foregroundPainter: _RimPainter(shape: shape, lit: lit, dim: dim),
      child: content,
    );
    if (blur) {
      // Shares one backdrop capture with the other panels of a page when
      // there is a [BackdropGroup] above (cheaper on Impeller).
      content = BackdropFilter.grouped(
        filter: ui.ImageFilter.compose(
          outer: const ColorFilter.matrix(_saturate),
          inner: ui.ImageFilter.blur(
            sigmaX: style.blur,
            sigmaY: style.blur,
            tileMode: TileMode.mirror,
          ),
        ),
        child: content,
      );
    }
    content = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: content,
    );
    if (shadow) {
      content = CustomPaint(
        painter: _ShadowPainter(shape: shape, color: style.shadow),
        child: content,
      );
    }
    return content;
  }

  /// Saturation x1.5: colours behind glass look richer, not washed out.
  static const _saturate = <double>[
    1.393, -0.357, -0.036, 0, 0, //
    -0.107, 1.143, -0.036, 0, 0, //
    -0.107, -0.357, 1.464, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// A soft drop shadow drawn only outside the panel, so it never darkens
/// the glass itself.
class _ShadowPainter extends CustomPainter {
  _ShadowPainter({required this.shape, required this.color});

  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(80)),
          path,
        ),
      )
      ..drawPath(
        path.shift(const Offset(0, 10)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.color != color || old.shape != shape;
}

class _RimPainter extends CustomPainter {
  _RimPainter({required this.shape, required this.lit, required this.dim});

  final ShapeBorder shape;
  final Color lit;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.6);
    // Light from the top-left; a softer reflection on the opposite edge.
    canvas.drawPath(
      shape.getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lit, dim, dim, Color.lerp(dim, lit, 0.5)!],
          stops: const [0, 0.4, 0.7, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.lit != lit || old.dim != dim || old.shape != shape;
}

/// The backdrop of every screen: a deep gradient with soft colour clouds.
/// [warmth] (0..1) raises a fire glow, used while connected.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.warmth = 0, required this.child});

  final double warmth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = GlassStyle.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: warmth),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, warmth, child) =>
            CustomPaint(painter: _AuroraPainter(style, warmth), child: child),
        child: child,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.style, this.warmth);

  final GlassStyle style;
  final double warmth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.background,
        ).createShader(rect),
    );
    final span = size.longestSide;
    void cloud(Offset center, double radius, Color color) {
      if (color.a == 0) return;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final [a, b, c] = style.blobs;
    cloud(Offset(size.width * 0.1, size.height * 0.04), span * 0.55, a);
    cloud(Offset(size.width * 1.0, size.height * 0.42), span * 0.45, b);
    cloud(Offset(size.width * 0.15, size.height * 0.95), span * 0.5, c);
    // The fire rises behind the top half, where the phoenix sits.
    cloud(
      Offset(size.width * 0.5, size.height * 0.3),
      span * (0.35 + 0.15 * warmth),
      style.ember.withValues(alpha: style.ember.a * (0.18 + 0.82 * warmth)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.warmth != warmth || old.style != style;
}

/// A [Scaffold] over the aurora, for pushed pages. Its glass panels share
/// one backdrop blur.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: BackdropGroup(child: body),
      floatingActionButton: floatingActionButton,
    ),
  );
}
