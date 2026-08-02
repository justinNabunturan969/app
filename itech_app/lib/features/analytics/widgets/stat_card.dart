import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.targetValue,
    required this.isPercent,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final int targetValue;
  final bool isPercent;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _value;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _value = Tween<double>(
      begin: 0,
      end: widget.targetValue.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    final val = v.round();
    if (!widget.isPercent) return '$val';
    return '$val%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = scheme.onSurface;
    final subtitleColor = isDark ? scheme.onSurfaceVariant : PupColors.ashGray;

    return AnimatedBuilder(
      animation: _value,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 148,
            padding: const EdgeInsets.all(12),
            decoration: _pressed
                ? PupGlass.pressedDecoration(
                    context: context,
                    accent: widget.tone,
                    borderRadius: 18,
                  )
                : PupGlass.statCardGlow(
                    context: context,
                    accent: widget.tone,
                    borderRadius: 18,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.tone.withValues(alpha: 0.32),
                        widget.tone.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.tone.withValues(alpha: 0.45),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.tone.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: widget.tone, size: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  _format(_value.value),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
