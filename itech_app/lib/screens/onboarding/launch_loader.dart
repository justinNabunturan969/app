import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session/auth_session_storage.dart';
import '../../main.dart';
import '../../theme/design_tokens.dart';

/// Branded launch loader — replaces the boring progress-bar with a smooth
/// zoom-in of the PUP-ITech wrench.
///
/// Shown:
///   - On every fresh app launch for already-signed-in users (skips the
///     first-run splash and goes straight to the home shell after the
///     zoom settles).
///   - Right after the student/admin login completes, before the home
///     shell appears — gives the user a moment of "we got you" feedback
///     and lets the realtime subscriptions start populating before the
///     UI mounts.
///
/// The animation is two layered effects: a soft amber glow ring that
/// scales in ahead of the wrench, and the wrench itself fading in
/// while scaling from 0.25x to 1.15x and settling to 1.0x with an
/// easeOut curve. Total duration ~1.5s — long enough to feel deliberate,
/// short enough that nobody is waiting on it.
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Fade in during the first 40% of the animation. By the time the
    // wrench reaches its peak scale, it's already at full opacity.
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    // A two-step tween: 0.25x → 1.15x with easeOutCubic (the "snap" in),
    // then 1.15x → 1.0x with easeOut (the "settle"). The 75/25 weight
    // gives the snap most of the duration so the settle is quick.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.25, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _runAndAdvance();
  }

  Future<void> _runAndAdvance() async {
    await _controller.forward();
    if (!mounted) return;
    // Route based on auth state: signed-in users go to their home
    // shell, everyone else lands on the welcome screen so the new-user
    // onboarding flow can take over from there.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Opacity(
                  opacity: _opacity.value * 0.7,
                  child: Container(
                    width: 200 * _scale.value,
                    height: 200 * _scale.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PupColors.cyberAmber.withValues(alpha: 0.45),
                          blurRadius: 60,
                          spreadRadius: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    // Material's build_rounded is a spanner/wrench glyph,
                    // font-based, scales perfectly with Transform.scale,
                    // and avoids the path-translation bugs the
                    // CustomPainter / SVG approaches kept hitting.
                    child: const Icon(
                      Icons.build_rounded,
                      size: 124,
                      color: PupColors.cyberAmber,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
