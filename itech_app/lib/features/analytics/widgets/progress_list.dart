import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class ProgressListItem extends StatefulWidget {
  const ProgressListItem({
    super.key,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.rightText,
  });

  final String title;
  final int value;
  final int maxValue;
  final Color color;
  final String rightText;

  @override
  State<ProgressListItem> createState() => _ProgressListItemState();
}

class _ProgressListItemState extends State<ProgressListItem>
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final denom = widget.maxValue == 0 ? 1 : widget.maxValue;
    final pct = (widget.value / denom).clamp(0.0, 1.0);

    // Track color: in light mode we use the explicit cool steel; in dark
    // mode we use a low-opacity onSurface so the bar is visible on the
    // dark card.
    final trackColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.12)
        : PupColors.coolSteel;
    final titleColor = scheme.onSurface;
    final rightColor = isDark ? scheme.onSurfaceVariant : PupColors.ashGray;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: titleColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.rightText,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: rightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(color: trackColor),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (pct * _anim.value).clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: widget.color),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
