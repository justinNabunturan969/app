import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class MonthlyActivityBarChart extends StatefulWidget {
  const MonthlyActivityBarChart({super.key, required this.data});

  final List<int> data;

  @override
  State<MonthlyActivityBarChart> createState() =>
      _MonthlyActivityBarChartState();
}

class _MonthlyActivityBarChartState extends State<MonthlyActivityBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Maximum bar height that fits inside the 120px chart area.
  /// Budget: text(≈16) + gap(4) + bar(this) + gap(6) + text(≈16) = 120.
  /// Reduced from 82 → 78 to compensate for text rendering at w900/w800
  /// being ~2px taller per line than the original ≈14px estimate,
  /// which was causing a ~4px bottom overflow on the tallest bar.
  static const double _maxBarHeight = 78;

  String _dayLabel(int index) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index.clamp(0, labels.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Defensive: if the data is empty OR all zeros, fall back to 1 so we
    // never end up with `0 / 0 = NaN` in the bar height calculation.
    final max = widget.data.isEmpty
        ? 1
        : widget.data.reduce((a, b) => a > b ? a : b);
    final safeMax = max <= 0 ? 1 : max;

    final titleColor = scheme.onSurface;
    final captionColor = isDark ? scheme.onSurfaceVariant : PupColors.ashGray;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: PupGlass.statCardGlow(
            context: context,
            accent: PupColors.cyberAmber,
            borderRadius: 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Weekly Activity',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PupColors.cyberAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: PupColors.cyberAmber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < widget.data.length; i++) ...[
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == widget.data.length - 1 ? 0 : 6,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${widget.data[i]}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Bar with gradient + glow
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: double.infinity,
                                  // Guard against NaN: if data[i] is 0,
                                  // 0 / safeMax is 0, multiplied by anim
                                  // is 0, then clamp(4.0, 78.0) gives 4.0.
                                  // Was previously producing a NaN height
                                  // when the entire data list was 0s.
                                  height:
                                      (_maxBarHeight *
                                              (widget.data[i] / safeMax) *
                                              _anim.value)
                                          .clamp(4.0, _maxBarHeight.toDouble()),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              PupColors.cyberAmber.withValues(
                                                alpha: 0.8,
                                              ),
                                              PupColors.cyberAmber,
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Subtle top highlight
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          height: 3,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _dayLabel(i),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: captionColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
