import 'package:flutter/material.dart';

/// Application-wide theme configuration for HL Control.
///
/// Implements a dark Material 3 / Material You theme with near-black background
/// surfaces and a vivid violet accent seed.
class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF045AED); // Haylou Vivid Blue
  static const Color backgroundColor = Color(0xFF0C0D12); // Sleek deep space color
  static const Color cardColor = Color(0xFF161722); // Elegant slightly lighter card surfaces

  /// Builds a [ThemeData] based on target brightness and optional dynamic Material You color scheme.
  static ThemeData buildTheme(Brightness brightness, ColorScheme? dynamicColorScheme) {
    final isDark = brightness == Brightness.dark;

    ColorScheme colorScheme;
    if (dynamicColorScheme != null) {
      colorScheme = dynamicColorScheme;
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        surface: isDark ? backgroundColor : null,
      );
    }

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? (dynamicColorScheme != null ? colorScheme.surface : backgroundColor)
          : null,
      cardTheme: CardThemeData(
        color: dynamicColorScheme != null
            ? Color.alphaBlend(
                colorScheme.primary.withOpacity(0.08),
                colorScheme.surface,
              )
            : (isDark ? cardColor : null),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.onSurface.withOpacity(0.24),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
