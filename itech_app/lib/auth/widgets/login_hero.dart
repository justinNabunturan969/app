import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Differentiated hero panel for the top of each login page.
///
/// - [accent] drives the glow / accent strip colour.
/// - [icon] is the role-appropriate big icon (graduation cap for student,
///   shield for admin, etc).
/// - [eyebrow] is the small kicker line ("Access Student Borrowing").
/// - [title] is the hero line ("Welcome back" / "Faculty Access").
class LoginHero extends StatelessWidget {
  const LoginHero({
    super.key,
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.tag,
  });

  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Color.lerp(PupColors.darkCard, accent, 0.10)!
        : Color.lerp(PupColors.lightCard, accent, 0.06)!;
    final borderColor = isDark
        ? accent.withValues(alpha: 0.45)
        : accent.withValues(alpha: 0.32);
    final textColor = isDark ? Colors.white : PupColors.slateGray;
    final subtleText = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : PupColors.slateGray.withValues(alpha: 0.78);
    // Bright accents (e.g. techCyan) fail WCAG AA as small text on the
    // near-white light-mode hero surface, so darken them toward black while
    // preserving hue. Already-dark accents (e.g. pupMaroon) and every
    // dark-mode accent stay as-is.
    final eyebrowColor =
        isDark ||
            ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? accent
        : Color.lerp(accent, Colors.black, 0.45)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardBg,
            isDark ? PupColors.darkCardAlt : PupColors.lightCardAlt,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.95),
                      accent.withValues(alpha: 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: eyebrowColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: PupColors.pupMaroon,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: subtleText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
