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

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          surface: backgroundColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        cardTheme: const CardThemeData(
          color: cardColor,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 6,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
          activeTrackColor: seedColor,
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
