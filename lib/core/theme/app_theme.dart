import 'package:flutter/material.dart';

import 'glass.dart';
import 'status_colors.dart';

/// Light and dark "liquid glass" themes in the phoenix's colours: ember
/// orange on a night (or pearl) aurora. Vazirmatn covers both Persian and
/// Latin glyphs, so one font family is used for every locale.
abstract final class AppTheme {
  static const Color seed = Color(0xFFFF6B2C);
  static const String fontFamily = 'Vazirmatn';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (brightness == Brightness.dark) {
      return base.copyWith(
        primary: const Color(0xFFFF9A4D),
        onPrimary: const Color(0xFF2B1100),
        primaryContainer: const Color(0xFF5C2A12),
        onPrimaryContainer: const Color(0xFFFFDCC6),
        secondary: const Color(0xFFFFC08A),
        tertiary: const Color(0xFFB9A2FF),
        onTertiary: const Color(0xFF22134D),
        tertiaryContainer: const Color(0xFF3A2C6E),
        onTertiaryContainer: const Color(0xFFE6DDFF),
        surface: const Color(0xFF0E0D22),
        onSurface: const Color(0xFFF4F1FF),
        onSurfaceVariant: const Color(0xFFB4AFCC),
        surfaceContainerLowest: const Color(0xFF0B0A1C),
        surfaceContainerLow: const Color(0xFF16152E),
        surfaceContainer: const Color(0xFF1C1B36),
        surfaceContainerHigh: const Color(0xFF24233F),
        surfaceContainerHighest: const Color(0xFF2D2C4A),
        outline: const Color(0xFF6E6A8C),
        outlineVariant: const Color(0x33FFFFFF),
        error: const Color(0xFFFF7A8A),
        inverseSurface: const Color(0xFFEDEAF7),
        onInverseSurface: const Color(0xFF1A1830),
        inversePrimary: const Color(0xFFC2410C),
      );
    }
    return base.copyWith(
      primary: const Color(0xFFC2410C),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE3D0),
      onPrimaryContainer: const Color(0xFF4F1600),
      secondary: const Color(0xFF9A4A1C),
      tertiary: const Color(0xFF6A4BD6),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFE8E0FF),
      onTertiaryContainer: const Color(0xFF21105C),
      surface: const Color(0xFFF6F3FB),
      onSurface: const Color(0xFF1B1630),
      onSurfaceVariant: const Color(0xFF5D5872),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFBF9FE),
      surfaceContainer: const Color(0xFFF4F1F9),
      surfaceContainerHigh: const Color(0xFFEEEAF5),
      surfaceContainerHighest: const Color(0xFFE7E2F0),
      outline: const Color(0xFF8E89A3),
      outlineVariant: const Color(0x1F1B1630),
      error: const Color(0xFFDC2626),
      inverseSurface: const Color(0xFF221E36),
      onInverseSurface: const Color(0xFFF4F1FF),
      inversePrimary: const Color(0xFFFF9A4D),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final glass = isDark ? GlassStyle.dark : GlassStyle.light;
    final radius = BorderRadius.circular(22);
    final rim = BorderSide(color: glass.rim.$1.withValues(alpha: 0.35));
    // Opaque enough to read over anything, still tinted like glass.
    final floating = Color.alphaBlend(
      glass.fill.$1,
      isDark ? const Color(0xF2141329) : const Color(0xF5FBF9FE),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      brightness: brightness,
    );
    final text = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [isDark ? StatusColors.dark : StatusColors.light, glass],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: glass.fill.$1,
        shape: RoundedSuperellipseBorder(borderRadius: radius, side: rim),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass.fill.$1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: rim,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: rim,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: floating,
        modalBackgroundColor: floating,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: floating,
        surfaceTintColor: Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(30),
          side: rim,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: floating,
        surfaceTintColor: Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
          side: rim,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(rim),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
                : glass.fill.$2,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline.withValues(alpha: 0.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
