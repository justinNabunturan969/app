import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';

/// A minimal, branded entry moment before the welcome screen.
///
/// The PUP-ITech mark fills the center of the display, zooms in, then settles
/// before the welcome page appears. There is deliberately no text or progress
/// control competing with the mark.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _markOpacity;
  late final Animation<double> _markScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _markOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _markScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.12,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _playIntro();
  }

  Future<void> _playIntro() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) context.go('/welcome');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      body: Center(
        child: FadeTransition(
          opacity: _markOpacity,
          child: ScaleTransition(
            scale: _markScale,
            child: SizedBox(
              width: 112,
              height: 112,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  PupColors.cyberAmber,
                  BlendMode.srcIn,
                ),
                child: Image.asset('assets/branding/pup_itech_source_icon.png'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
