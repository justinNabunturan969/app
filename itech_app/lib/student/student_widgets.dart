import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class PupTapEffect extends StatelessWidget {
  const PupTapEffect({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

class GlowAmber extends StatelessWidget {
  const GlowAmber({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        // A subtle always-on glow via implicit animation on size/opacity
        const AlwaysStoppedAnimation(0),
      ]),
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: PupColors.cyberAmber.withValues(alpha: 0.35),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

class BadgeDot extends StatelessWidget {
  const BadgeDot({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Positioned(
      top: 3,
      right: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: PupColors.signalRed,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: PupColors.signalRed.withValues(alpha: 0.35),
              blurRadius: 10,
            ),
          ],
        ),
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 300),
  });

  final int value;
  final Duration duration;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _from = (oldWidget.value == 0) ? 0 : oldWidget.value;
    _c.duration = widget.duration;
    _anim = Tween<double>(
      begin: _from.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Text(
          _anim.value.round().toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        );
      },
    );
  }
}

class PulseGlow extends StatefulWidget {
  const PulseGlow({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.25,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _opacity.value),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

class CountdownPill extends StatefulWidget {
  const CountdownPill({super.key, required this.remaining});

  final Duration remaining;

  // ignore: prefer_final_fields

  @override
  State<CountdownPill> createState() => _CountdownPillState();
}

class _CountdownPillState extends State<CountdownPill> {
  static String _format(Duration d) {
    final s = d.inSeconds;
    final absS = s.abs();
    final hours = absS ~/ 3600;
    final minutes = (absS % 3600) ~/ 60;
    final sign = s < 0 ? '-' : '';
    if (hours > 0) {
      return '$sign${hours}h ${minutes}m';
    }
    return '$sign${minutes}m';
  }

  Color _tone() {
    final d = widget.remaining;
    if (d.isNegative) return PupColors.signalRed;
    if (d.inMinutes < 60) return PupColors.signalRed;
    if (d.inHours < 24) return PupColors.cyberAmber;
    return PupColors.mintGreen;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone();
    final isCritical =
        tone == PupColors.signalRed && !widget.remaining.isNegative;

    Widget content = Text(
      _format(widget.remaining),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.95),
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    );

    if (isCritical) {
      content = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 1.05),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        builder: (_, v, _) => Transform.scale(scale: v, child: content),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: content,
    );
  }
}

class StaggeredSlideUpList extends StatelessWidget {
  const StaggeredSlideUpList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.stagger = 50,
  });

  final int items;
  final int stagger;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        return Stack(
          children: [
            // placeholder to keep layout same
          ],
        );
      },
    );
  }
}
