import 'package:flutter/material.dart';

/// PUP-ITech design tokens.
///
/// Colors are strictly aligned to the provided palette.
class PupColors {
  // Primary
  static const Color pupMaroon = Color(0xFF7B1818); // #7B1818
  static const Color pupMaroonAlt = Color(0xFF8B0000); // #8B0000

  /// Dark-mode counterpart of [pupMaroon]: same hue family but light enough
  /// to read as text/icon on carbon and darkCard surfaces (>= 4.5:1).
  static const Color pupMaroonBright = Color(0xFFFF6B6B); // #FF6B6B

  /// Brand maroon for text/icons: stays readable on the active surface.
  static Color brand(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? pupMaroonBright
      : pupMaroon;

  // Primary Dark
  static const Color deepMahogany = Color(0xFF4A0E0E); // #4A0E0E

  // Secondary
  static const Color coolSteel = Color(0xFFF0F2F5); // #F0F2F5

  // Accent 1
  static const Color cyberAmber = Color(0xFFFFB800); // #FFB800

  /// Deep amber for light-mode text: [cyberAmber] fails WCAG AA on white
  /// (~1.7:1); this clears it (~5.5:1) while staying in the amber family.
  static const Color amberDeep = Color(0xFF8A6100); // #8A6100

  /// Amber accent for text/icons that must stay readable on the active surface.
  /// Bright [cyberAmber] on dark, deep [amberDeep] on light.
  static Color amberText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cyberAmber : amberDeep;

  // Accent 2
  static const Color techCyan = Color(0xFF00B4D8); // #00B4D8

  /// Deeper cyan for light-mode text: [techCyan] fails WCAG AA on white
  /// (~2.5:1); this clears it (~5.4:1) while staying in the cyan family.
  static const Color cyanDeep = Color(0xFF0E7490); // #0E7490

  /// Cyan accent for text/icons that must stay readable on the active surface.
  /// Bright [techCyan] on dark, deeper [cyanDeep] on light.
  static Color accentText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? techCyan : cyanDeep;

  // Success
  static const Color mintGreen = Color(0xFF06D6A0); // #06D6A0

  /// Deep green for light-mode text: [mintGreen] fails WCAG AA on white
  /// (~1.9:1); this clears it (~5.5:1) while staying in the green family.
  static const Color greenDeep = Color(0xFF047857); // #047857

  /// Success accent for text/icons that must stay readable on the active
  /// surface. Bright [mintGreen] on dark, deep [greenDeep] on light.
  static Color successText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? mintGreen : greenDeep;

  /// Light-mode-readable variant of a runtime status [tone].
  ///
  /// Status chips across the app paint their label with the same tone that
  /// drives a pale tinted background. The bright accents (cyan/amber/green)
  /// fail WCAG AA as small text on those near-white light-mode surfaces, so
  /// deepen them to [cyanDeep]/[amberDeep]/[greenDeep]. Dark mode and tones
  /// that are already readable (maroon, red, gray) pass through unchanged.
  /// Also valid as a solid fill under white text.
  static Color readableTone(BuildContext context, Color tone) {
    if (Theme.of(context).brightness == Brightness.dark) return tone;
    if (tone == techCyan) return cyanDeep;
    if (tone == cyberAmber) return amberDeep;
    if (tone == mintGreen) return greenDeep;
    return tone;
  }

  // Danger
  static const Color signalRed = Color(0xFFEF476F); // #EF476F

  // Text
  static const Color slateGray = Color(0xFF1E293B); // #1E293B
  static const Color ashGray = Color(0xFF64748B); // #64748B

  // Light mode card surface - opaque white with subtle tint
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFF8F9FC);

  /// Light mode elevated surfaces (glass-like) with amber/cyan glow
  static const Color lightGlowAmber = Color(0xFFFFF8E1);
  static const Color lightGlowCyan = Color(0xFFE1F7FF);
  static const Color lightGlowGreen = Color(0xFFE1FCF0);
  static const Color lightGlowRed = Color(0xFFFFE8EE);

  // Dark mode card surfaces
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardAlt = Color(0xFF162032);
}

/// Helper to build glowing container decorations that work in **both** light and dark mode.
///
/// In dark mode the glow reads as a bright rim light; in light mode it reads
/// as a subtle tinted elevation — just like the dark-mode vibe, but visible
/// and beautiful on a light background.
class PupGlass {
  PupGlass._();

  // ── Light-mode helpers ──────────────────────────────────────────────

  /// Card fill for light mode — white with a **very** subtle tint overlay.
  static Color lightFill(Color accent) =>
      Color.lerp(PupColors.lightCard, accent, 0.04)!;

  /// Light mode border — tinted but still crisp.
  static Color lightBorder(Color accent) => accent.withValues(alpha: 0.25);

  /// Light mode shadow — uses the accent colour so the card "glows" in kind.
  static List<BoxShadow> lightShadow(
    Color accent, {
    double blur = 16,
    double offsetY = 6,
  }) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.18),
      blurRadius: blur,
      offset: Offset(0, offsetY),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Light mode pastel ambient glow — a soft, eye-friendly halo using
  /// desaturated pastel versions of the accent color. Ideal for stat cards
  /// and elevated containers on white/light backgrounds.
  static List<BoxShadow> lightPastelGlow(
    Color accent, {
    double blur = 32,
    double spread = 4,
    double offsetY = 8,
  }) {
    // Create a pastel/desaturated version of the accent
    final hsl = HSLColor.fromColor(accent);
    final pastel = hsl
        .withLightness((hsl.lightness + 0.65).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
        .toColor();

    return [
      BoxShadow(
        color: pastel.withValues(alpha: 0.35),
        blurRadius: blur,
        spreadRadius: spread,
        offset: Offset(0, offsetY),
      ),
      BoxShadow(
        color: pastel.withValues(alpha: 0.15),
        blurRadius: 18,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // ── Dark-mode helpers ───────────────────────────────────────────────

  static Color darkFill(Color accent) =>
      Color.lerp(PupColors.darkCard, accent, 0.12)!;

  static Color darkBorder(Color accent) => accent.withValues(alpha: 0.35);

  static List<BoxShadow> darkShadow(
    Color accent, {
    double blur = 18,
    double offsetY = 8,
  }) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.25),
      blurRadius: blur,
      offset: Offset(0, offsetY),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Enhanced dark mode glow with inner and outer glow components.
  /// Creates a luminous rim light around the card with a subtle inner
  /// glow for depth.
  static List<BoxShadow> darkEnhancedGlow(
    Color accent, {
    double outerBlur = 28,
    double innerBlur = 16,
    double offsetY = 10,
  }) => [
    // Outer ambient glow
    BoxShadow(
      color: accent.withValues(alpha: 0.20),
      blurRadius: outerBlur,
      spreadRadius: 3,
      offset: Offset(0, offsetY),
    ),
    // Outer focused rim
    BoxShadow(
      color: accent.withValues(alpha: 0.30),
      blurRadius: innerBlur,
      spreadRadius: 1,
      offset: Offset(0, offsetY * 0.5),
    ),
    // Inner glow (simulated via dark base shadow underneath)
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  /// Colored accent shadow for light mode — replaces generic grey shadows
  /// with a soft tinted shadow that complements the card's accent color.
  static List<BoxShadow> coloredShadow(
    Color accent, {
    double blur = 14,
    double offsetY = 6,
  }) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.12),
      blurRadius: blur,
      spreadRadius: 1,
      offset: Offset(0, offsetY),
    ),
    BoxShadow(
      color: accent.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Glow decoration specifically for small status ribbons/diagonal tags
  /// such as "Available" / "Borrowed". Compact and focused.
  static List<BoxShadow> statusRibbonGlow(Color accent, {bool isDark = false}) {
    if (isDark) {
      return [
        BoxShadow(
          color: accent.withValues(alpha: 0.45),
          blurRadius: 14,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.20),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: accent.withValues(alpha: 0.25),
        blurRadius: 10,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: accent.withValues(alpha: 0.10),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // ── Unified builders ───────────────────────────────────────────────

  /// Returns a [BoxDecoration] that works beautifully in both themes.
  ///
  /// [accent] is the dominant colour used for the tint / glow (e.g. amber,
  /// cyan, green, red).
  static BoxDecoration container({
    required BuildContext context,
    required Color accent,
    double borderRadius = 18,
    double borderWidth = 1.2,
    double blur = 16,
    double offsetY = 6,
    bool usePastelGlow = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = isDark ? darkFill(accent) : lightFill(accent);
    final border = isDark ? darkBorder(accent) : lightBorder(accent);
    final shadows = isDark
        ? darkEnhancedGlow(accent, outerBlur: blur + 4, offsetY: offsetY + 2)
        : (usePastelGlow
              ? lightPastelGlow(accent, blur: blur + 8, offsetY: offsetY + 2)
              : lightShadow(accent, blur: blur, offsetY: offsetY));

    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: borderWidth),
      boxShadow: shadows,
    );
  }

  /// Returns a [BoxDecoration] specifically for glowing **containers with
  /// stronger visual emphasis** (e.g. stat cards, highlighted equipment).
  static BoxDecoration glowContainer({
    required BuildContext context,
    required Color accent,
    double borderRadius = 18,
    double borderWidth = 1.4,
    bool usePastelGlow = false,
  }) {
    return container(
      context: context,
      accent: accent,
      borderRadius: borderRadius,
      borderWidth: borderWidth,
      blur: 24,
      offsetY: 8,
      usePastelGlow: usePastelGlow,
    );
  }

  /// Returns a decoration for stat cards with the most visually appealing
  /// glow treatment for each mode. In light mode uses pastel ambient glow;
  /// in dark mode uses enhanced rim + inner glow.
  static BoxDecoration statCardGlow({
    required BuildContext context,
    required Color accent,
    double borderRadius = 18,
  }) {
    return glowContainer(
      context: context,
      accent: accent,
      borderRadius: borderRadius,
      usePastelGlow: true,
    );
  }

  /// Pressed/active state decoration for interactive cards, providing
  /// visual feedback without being too strong.
  static BoxDecoration pressedDecoration({
    required BuildContext context,
    required Color accent,
    double borderRadius = 18,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Color.lerp(PupColors.darkCard, accent, 0.20)!
        : Color.lerp(PupColors.lightCardAlt, accent, 0.08)!;

    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: accent.withValues(alpha: isDark ? 0.50 : 0.35),
        width: 1.5,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: accent.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }
}

/// Shortcut for the most common "subtle glass" decoration call.
BoxDecoration glassDecoration(
  BuildContext context,
  Color accent, {
  double borderRadius = 18,
  double? blur,
}) {
  return PupGlass.container(
    context: context,
    accent: accent,
    borderRadius: borderRadius,
    blur: blur ?? 16,
  );
}

/// Shortcut for a glowing decoration with stronger emphasis.
BoxDecoration glowDecoration(
  BuildContext context,
  Color accent, {
  double borderRadius = 18,
}) {
  return PupGlass.glowContainer(context: context, accent: accent);
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
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: fontFamily),
      bodySmall: base.bodySmall?.copyWith(fontFamily: fontFamily),
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
        surface: PupColors.lightCardAlt,
        error: PupColors.signalRed,
      ),
      scaffoldBackgroundColor: PupColors.coolSteel,
      appBarTheme: const AppBarTheme(
        backgroundColor: PupColors.pupMaroon,
        foregroundColor: Colors.white,
      ),
      cardColor: PupColors.lightCard,
      dividerColor: PupColors.ashGray.withValues(alpha: 0.18),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PupColors.cyberAmber,
        foregroundColor: Color(0xFF1B1B1B),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PupColors.lightCardAlt,
        selectedItemColor: PupColors.cyberAmber,
        unselectedItemColor: PupColors.ashGray,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PupColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: PupColors.ashGray.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: PupColors.ashGray.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: PupColors.cyberAmber.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        labelStyle: TextStyle(color: PupColors.slateGray),
        hintStyle: TextStyle(color: PupColors.ashGray.withValues(alpha: 0.7)),
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
        primary: PupColors.pupMaroonBright,
        onPrimary: PupColors.deepMahogany,
        secondary: PupColors.techCyan,
        surface: carbon,
        error: PupColors.signalRed,
      ),
      scaffoldBackgroundColor: carbon,
      appBarTheme: const AppBarTheme(
        backgroundColor: PupColors.deepMahogany,
        foregroundColor: Colors.white,
      ),
      cardColor: PupColors.darkCard,
      dividerColor: Colors.white.withValues(alpha: 0.08),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PupColors.cyberAmber,
        foregroundColor: Color(0xFF0B0B0B),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PupColors.deepMahogany,
        selectedItemColor: PupColors.cyberAmber,
        unselectedItemColor: Colors.white70,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PupColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: PupColors.cyberAmber.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
      ),
      textTheme: PupTypography.textThemeFor(ThemeData.dark().textTheme),
    );
  }
}
