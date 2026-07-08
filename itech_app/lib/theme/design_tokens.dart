import 'package:flutter/material.dart';

/// PUP-ITech design tokens.
///
/// Colors are strictly aligned to the provided palette.
class PupColors {
  // Primary
  static const Color pupMaroon = Color(0xFF7B1818); // #7B1818
  static const Color pupMaroonAlt = Color(0xFF8B0000); // #8B0000

  // Primary Dark
  static const Color deepMahogany = Color(0xFF4A0E0E); // #4A0E0E

  // Secondary
  static const Color coolSteel = Color(0xFFF0F2F5); // #F0F2F5

  // Accent 1
  static const Color cyberAmber = Color(0xFFFFB800); // #FFB800

  // Accent 2
  static const Color techCyan = Color(0xFF00B4D8); // #00B4D8

  // Success
  static const Color mintGreen = Color(0xFF06D6A0); // #06D6A0

  // Danger
  static const Color signalRed = Color(0xFFEF476F); // #EF476F

  // Text
  static const Color slateGray = Color(0xFF1E293B); // #1E293B
  static const Color ashGray = Color(0xFF64748B); // #64748B
}

class PupTypography {
  static const String fontFamily = 'Inter';

  static TextTheme textThemeFor(TextTheme base) {
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        color: PupColors.slateGray,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        color: PupColors.slateGray,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        color: PupColors.slateGray,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: fontFamily,
        color: PupColors.ashGray,
      ),
    );
  }
}

class PupTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PupColors.pupMaroon,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        primary: PupColors.pupMaroon,
        secondary: PupColors.techCyan,
        surface: PupColors.coolSteel,
        error: PupColors.signalRed,
      ),
      scaffoldBackgroundColor: PupColors.coolSteel,
      appBarTheme: const AppBarTheme(
        backgroundColor: PupColors.pupMaroon,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PupColors.cyberAmber,
        foregroundColor: Color(0xFF1B1B1B),
      ),
      textTheme: PupTypography.textThemeFor(ThemeData.light().textTheme),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PupColors.pupMaroon,
      brightness: Brightness.dark,
    );

    const carbon = Color(0xFF0F172A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        primary: PupColors.pupMaroon,
        secondary: PupColors.techCyan,
        surface: carbon,
        error: PupColors.signalRed,
      ),
      scaffoldBackgroundColor: carbon,
      appBarTheme: const AppBarTheme(
        backgroundColor: PupColors.deepMahogany,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PupColors.cyberAmber,
        foregroundColor: Color(0xFF0B0B0B),
      ),
      textTheme: PupTypography.textThemeFor(ThemeData.dark().textTheme),
    );
  }
}
