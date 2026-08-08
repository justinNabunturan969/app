import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';

/// A minimal, branded entry moment before the welcome screen.
///
/// The welcome-page mark scales into place at the center of the display,
/// rather than showing a conventional progress indicator.
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
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _markScale = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
    return const Scaffold(
      backgroundColor: Color(0xFF08090B),
      body: _LaunchMark(),
    );
  }
}

class _LaunchMark extends StatelessWidget {
  const _LaunchMark();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SplashScreenState>()!;
    return Center(
      child: FadeTransition(
        opacity: state._markOpacity,
        child: ScaleTransition(
          scale: state._markScale,
          child: Container(
            width: 124,
            height: 124,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: PupColors.cyberAmber.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PupColors.cyberAmber.withValues(alpha: 0.18),
                  blurRadius: 42,
                  spreadRadius: 8,
                ),
              ],
            ),
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
    );
  }
}
