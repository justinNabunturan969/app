import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session/auth_session_storage.dart';
import '../../main.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/launch_wrench_icon.dart';

/// Branded launch loader — a single glowing wrench zooms in until it
/// fills the screen, then routes to the next destination.
class LaunchLoader extends StatefulWidget {
  const LaunchLoader({super.key});

  @override
  State<LaunchLoader> createState() => _LaunchLoaderState();
}

class _LaunchLoaderState extends State<LaunchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  static const _wrenchSize = 124.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    );

    _runAndAdvance();
  }

  Future<void> _runAndAdvance() async {
    await _controller.forward();
    if (!mounted) return;
    final loggedIn = await authSessionStorage.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      context.go('/welcome');
      return;
    }
    final role = await authSessionStorage.getRole();
    if (!mounted) return;
    final dest = switch (role) {
      UserRole.admin => '/admin/shell',
      _ => '/student/shell',
    };
    context.go(dest);
  }

  double _fillScale(Size screen) {
    final diagonal = math.sqrt(
      screen.width * screen.width + screen.height * screen.height,
    );
    return (diagonal / _wrenchSize) * 1.08;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final beginScale = 0.18;
    final endScale = _fillScale(screen);

    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final currentScale =
              beginScale + (endScale - beginScale) * _scale.value;

          return Center(
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: currentScale,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: PupColors.cyberAmber.withValues(alpha: 0.55),
                        blurRadius: 48,
                        spreadRadius: 18,
                      ),
                      BoxShadow(
                        color: PupColors.cyberAmber.withValues(alpha: 0.25),
                        blurRadius: 90,
                        spreadRadius: 36,
                      ),
                    ],
                  ),
                  child: const LaunchWrenchIcon(size: _wrenchSize),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
