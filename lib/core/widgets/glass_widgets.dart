import 'package:flutter/material.dart';

import '../theme/glass.dart';
import '../utils/context_ext.dart';

/// Round glass button with an icon, for screen headers.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Glass(
          circle: true,
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: size * 0.48,
              color: onPressed == null
                  ? context.colors.onSurface.withValues(alpha: 0.38)
                  : color ?? context.colors.onSurface,
            ),
          ),
        ),
      ),
    ),
  );
}

/// iOS-style large title with optional trailing [actions].
class LargeTitle extends StatelessWidget {
  const LargeTitle({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 12, 16, 8),
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.textTheme.headlineMedium,
          ),
        ),
        for (final (i, action) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          action,
        ],
      ],
    ),
  );
}

/// Small muted heading above a [GlassGroup].
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
    child: Text(
      text,
      style: context.theme.textTheme.labelLarge?.copyWith(
        color: context.colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// An inset group of rows on one glass panel, separated by hairlines.
class GlassGroup extends StatelessWidget {
  const GlassGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 0.6,
      indent: 64,
      color: context.colors.outlineVariant,
    );
    return Padding(
      padding: margin,
      child: Glass(
        blur: false,
        radius: 26,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) divider,
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// White glyph on a coloured squircle, the leading icon of a settings row.
class TileIcon extends StatelessWidget {
  const TileIcon(this.icon, this.color, {super.key});

  final IconData icon;
  final Color color;

  static const orange = Color(0xFFFF8A2B);
  static const red = Color(0xFFFF4D5E);
  static const pink = Color(0xFFFF4F8B);
  static const purple = Color(0xFFA55EEA);
  static const indigo = Color(0xFF5E5CE6);
  static const blue = Color(0xFF2F8CFF);
  static const teal = Color(0xFF22B8CF);
  static const green = Color(0xFF2FBF71);
  static const gold = Color(0xFFF2B43A);
  static const gray = Color(0xFF8A8AA0);

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: ShapeDecoration(
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(9)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, 0.18)!, color],
      ),
    ),
    child: Icon(icon, size: 19, color: Colors.white),
  );
}

/// A [GlassIconButton] that opens a popup menu.
class GlassMenuButton<T> extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.itemBuilder,
    this.onSelected,
    this.initialValue,
  });

  final IconData icon;
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final T? initialValue;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: tooltip,
    initialValue: initialValue,
    onSelected: onSelected,
    itemBuilder: itemBuilder,
    position: PopupMenuPosition.under,
    child: SizedBox.square(
      dimension: 44,
      child: Glass(
        circle: true,
        child: Center(
          child: Icon(icon, size: 21, color: context.colors.onSurface),
        ),
      ),
    ),
  );
}

/// The primary call to action: a capsule of fire.
class FireButton extends StatelessWidget {
  const FireButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      shape: StadiumBorder(),
      gradient: LinearGradient(colors: [Color(0xFFD03F0C), Color(0xFFB0174A)]),
      shadows: [
        BoxShadow(
          color: Color(0x55E8590C),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
