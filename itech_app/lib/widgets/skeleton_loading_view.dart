import 'package:flutter/material.dart';

/// A reusable skeleton ("shimmer") loading view used while the app fetches
/// its initial data from Supabase. Instead of a bare spinner, it renders a
/// layout-shaped placeholder that pulses gently, which reads as far more
/// polished and communicates *what* is loading.
class SkeletonLoadingView extends StatefulWidget {
  const SkeletonLoadingView({super.key, this.showHeader = true});

  /// Whether to draw the avatar + title header block (used by the shells'
  /// dashboard-like layouts).
  final bool showHeader;

  @override
  State<SkeletonLoadingView> createState() => _SkeletonLoadingViewState();
}

class _SkeletonLoadingViewState extends State<SkeletonLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _fade = Tween(
    begin: 0.35,
    end: 0.85,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black;
    final accent = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              if (widget.showHeader) ...[
                Row(
                  children: [
                    _Bone(size: 52, base: base, accent: accent, round: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bone(
                            height: 14,
                            width: 140,
                            base: base,
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          _Bone(
                            height: 10,
                            width: 90,
                            base: base,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              // Stat cards row
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 12),
                      child: _Card(
                        base: base,
                        accent: accent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bone(
                              height: 10,
                              width: 56,
                              base: base,
                              accent: accent,
                            ),
                            const SizedBox(height: 10),
                            _Bone(
                              height: 20,
                              width: 44,
                              base: base,
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Hero / chart block
              _Card(
                base: base,
                accent: accent,
                height: 150,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _Bone(
                    height: 12,
                    width: 120,
                    base: base,
                    accent: accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // List rows
              ...List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Card(
                    base: base,
                    accent: accent,
                    child: Row(
                      children: [
                        _Bone(
                          size: 40,
                          base: base,
                          accent: accent,
                          round: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Bone(
                                height: 11,
                                width: double.infinity,
                                base: base,
                                accent: accent,
                              ),
                              const SizedBox(height: 7),
                              _Bone(
                                height: 9,
                                width: 120,
                                base: base,
                                accent: accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Bone(
                          height: 22,
                          width: 58,
                          base: base,
                          accent: accent,
                          round: true,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded placeholder block.
class _Bone extends StatelessWidget {
  const _Bone({
    required this.base,
    required this.accent,
    this.height,
    this.width,
    this.size,
    this.round = false,
  });

  final Color base;
  final Color accent;
  final double? height;
  final double? width;
  final double? size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final w = size ?? width;
    final h = size ?? height ?? 12.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(round ? 999 : 8),
        border: Border.all(color: accent.withValues(alpha: 0.06)),
      ),
    );
  }
}

/// A card-shaped container that groups bones, mimicking the app's cards.
class _Card extends StatelessWidget {
  const _Card({
    required this.base,
    required this.accent,
    required this.child,
    this.height,
  });

  final Color base;
  final Color accent;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
