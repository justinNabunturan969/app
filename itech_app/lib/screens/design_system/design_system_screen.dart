import 'package:flutter/material.dart';

import '../../app/theme_menu_button.dart';
import '../../theme/design_tokens.dart';

/// In-app Design System showcase.
///
/// Live, interactive reference of the PUP-ITech visual language:
///   • Color tokens (brand, accents, text, surfaces)
///   • Typography scale
///   • Component examples (icon chips, pills, chips, buttons, stat tiles)
///   • PupGlass surface treatment (light & dark comparison)
///
/// Linked from Profile → Support → "Design System". Toggling the theme
/// here re-renders the whole page so you can show light/dark in one move
/// during the defense.
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
        : PupColors.ashGray;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: primaryText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Design System',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: primaryText,
                            ),
                          ),
                        ),
                        const ThemeMenuButton(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'PUP-ITech visual language — tokens, type, and components.',
                        style: TextStyle(
                          color: subtleText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Brand
                    _SectionHeader(
                      title: 'Brand',
                      icon: Icons.bookmark_rounded,
                      accent: PupColors.pupMaroon,
                    ),
                    const SizedBox(height: 10),
                    _ColorGrid(specs: _brandSpecs),
                    const SizedBox(height: 18),

                    // Accents
                    _SectionHeader(
                      title: 'Accents',
                      icon: Icons.palette_rounded,
                      accent: PupColors.cyberAmber,
                    ),
                    const SizedBox(height: 10),
                    _ColorGrid(specs: _accentSpecs),
                    const SizedBox(height: 18),

                    // Text
                    _SectionHeader(
                      title: 'Text',
                      icon: Icons.text_fields_rounded,
                      accent: PupColors.slateGray,
                    ),
                    const SizedBox(height: 10),
                    _ColorGrid(specs: _textSpecs),
                    const SizedBox(height: 18),

                    // Typography
                    _SectionHeader(
                      title: 'Typography',
                      icon: Icons.title_rounded,
                      accent: PupColors.techCyan,
                    ),
                    const SizedBox(height: 10),
                    _TypographyShowcase(),
                    const SizedBox(height: 18),

                    // Components
                    _SectionHeader(
                      title: 'Components',
                      icon: Icons.widgets_rounded,
                      accent: PupColors.mintGreen,
                    ),
                    const SizedBox(height: 10),
                    _ComponentsShowcase(),
                    const SizedBox(height: 18),

                    // Surfaces
                    _SectionHeader(
                      title: 'Surfaces',
                      icon: Icons.layers_rounded,
                      accent: PupColors.pupMaroon,
                    ),
                    const SizedBox(height: 10),
                    _SurfacesShowcase(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Color tokens
// ─────────────────────────────────────────────────────────────────────────

class _ColorSpec {
  const _ColorSpec(this.name, this.color, this.hex);
  final String name;
  final Color color;
  final String hex;
}

const _brandSpecs = [
  _ColorSpec('pupMaroon', PupColors.pupMaroon, '#7B1818'),
  _ColorSpec('deepMahogany', PupColors.deepMahogany, '#4A0E0E'),
  _ColorSpec('coolSteel', PupColors.coolSteel, '#F0F2F5'),
];

const _accentSpecs = [
  _ColorSpec('cyberAmber', PupColors.cyberAmber, '#FFB800'),
  _ColorSpec('techCyan', PupColors.techCyan, '#00B4D8'),
  _ColorSpec('mintGreen', PupColors.mintGreen, '#06D6A0'),
  _ColorSpec('signalRed', PupColors.signalRed, '#EF476F'),
];

const _textSpecs = [
  _ColorSpec('slateGray', PupColors.slateGray, '#1E293B'),
  _ColorSpec('ashGray', PupColors.ashGray, '#64748B'),
];

/// Returns black or white depending on the surface luminance so swatch
/// labels are always legible.
Color _onColor(Color bg) {
  return bg.computeLuminance() > 0.55 ? const Color(0xFF1B1B1B) : Colors.white;
}

class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.specs});
  final List<_ColorSpec> specs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns, equal width.
        const gap = 10.0;
        final w = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final s in specs) _ColorSwatch(spec: s, width: w)],
        );
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.spec, required this.width});
  final _ColorSpec spec;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fg = _onColor(spec.color);
    return Container(
      width: width,
      height: 92,
      decoration: BoxDecoration(
        color: spec.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            spec.name,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          Text(
            spec.hex,
            style: TextStyle(
              color: fg.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Typography
// ─────────────────────────────────────────────────────────────────────────

class _TypographyShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
        : PupColors.ashGray;

    return Container(
      decoration: PupGlass.container(
        context: context,
        accent: PupColors.techCyan,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display · 22 w900',
            style: TextStyle(
              color: titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PUP-ITech Borrowing',
            style: TextStyle(
              color: subtleText,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Title · 15 w900',
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Body · 13 w700 — the default reading style. Used for card titles, list rows, and most content surfaces.',
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'LABEL · 11 w800',
            style: TextStyle(
              color: subtleText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Caption · 12 w700 — secondary text, timestamps, helper lines.',
            style: TextStyle(
              color: subtleText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Components
// ─────────────────────────────────────────────────────────────────────────

class _ComponentsShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;

    return Container(
      decoration: PupGlass.container(
        context: context,
        accent: PupColors.mintGreen,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toned icon chip',
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _DsIconChip(icon: Icons.bolt_rounded, tone: PupColors.techCyan),
              SizedBox(width: 12),
              _DsIconChip(
                icon: Icons.warning_amber_rounded,
                tone: PupColors.signalRed,
              ),
              SizedBox(width: 12),
              _DsIconChip(
                icon: Icons.check_circle_rounded,
                tone: PupColors.mintGreen,
              ),
              SizedBox(width: 12),
              _DsIconChip(icon: Icons.bolt_rounded, tone: PupColors.cyberAmber),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Status pill',
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _DsStatusPill(label: 'Active', color: PupColors.techCyan),
              _DsStatusPill(label: 'Overdue', color: PupColors.signalRed),
              _DsStatusPill(label: 'Returned', color: PupColors.mintGreen),
              _DsStatusPill(label: 'Pending', color: PupColors.cyberAmber),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Buttons',
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: PupColors.cyberAmber,
                    foregroundColor: const Color(0xFF1B1B1B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Primary',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PupColors.brand(context),
                    side: BorderSide(
                      color: PupColors.brand(context).withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Secondary',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Surfaces
// ─────────────────────────────────────────────────────────────────────────

class _SurfacesShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SurfacePreview(
          label: 'PupGlass · mintGreen accent',
          accent: PupColors.mintGreen,
        ),
        const SizedBox(height: 10),
        _SurfacePreview(
          label: 'PupGlass · cyberAmber accent',
          accent: PupColors.cyberAmber,
        ),
        const SizedBox(height: 10),
        _SurfacePreview(
          label: 'PupGlass · techCyan accent',
          accent: PupColors.techCyan,
        ),
      ],
    );
  }
}

class _SurfacePreview extends StatelessWidget {
  const _SurfacePreview({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final subtleText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : PupColors.ashGray;

    return Container(
      decoration: PupGlass.statCardGlow(
        context: context,
        accent: accent,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _DsIconChip(icon: Icons.layers_rounded, tone: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Same component, two themes — try the toggle up top.',
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section header — mirrors the Profile's _Section pattern
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
  });
  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: titleColor,
            ),
          ),
        ),
        Container(
          height: 3,
          width: 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Local widget copies (so the file is self-contained)
// ─────────────────────────────────────────────────────────────────────────

class _DsIconChip extends StatelessWidget {
  const _DsIconChip({required this.icon, required this.tone});
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: 0.32), tone.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: tone, size: 22),
    );
  }
}

class _DsStatusPill extends StatelessWidget {
  const _DsStatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
