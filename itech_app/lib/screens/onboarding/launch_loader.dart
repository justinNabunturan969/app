import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session/auth_session_storage.dart';
import '../../main.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/launch_wrench_icon.dart';

/// The app's universal entry animation.
///
/// The wrench sits at center-bottom, pops into place, then shoots straight
/// up off the top of the screen with an accelerating ("blast-off") curve.
/// As it clears the top, the brand wordmark types itself in below the
/// launch point and we route to the next destination.
class LaunchLoader extends StatefulWidget {
  const LaunchLoader({super.key});

  @override
  State<LaunchLoader> createState() => _LaunchLoaderState();
}

class _LaunchLoaderState extends State<LaunchLoader>
    with SingleTickerProviderStateMixin {
  static const _appName = 'ITech App';
  static const _wrenchSize = 96.0;

  late final AnimationController _controller;
  late final Animation<double> _wrenchOpacity;
  late final Animation<double> _wrenchScale;
  late final Animation<Offset> _wrenchOffset;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Wrench visibility: quick fade-in (0-8%), stay visible, fade out at the
    // very end (90-100%) so it doesn't visibly clip the top edge — it
    // dissolves into the dark background.
    _wrenchOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 82),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_controller);

    // Wrench scale: a small "anticipation → release → fly" beat.
    // 0.65 → 0.9 (compress), 0.9 → 1.06 (release with slight overshoot),
    // 1.06 → 1.0 (settle) — gives it a launchpad feel before it blasts off.
    _wrenchScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.65, end: 0.9)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 82,
      ),
    ]).animate(_controller);

    // The actual upward shoot. The big range in Offset units (via
    // FractionalTranslation) clears the top edge on any device height.
    // easeInCubic — slow start, then accelerates — reads as "launched".
    _wrenchOffset = Tween<Offset>(
      begin: const Offset(0, 1.4),
      end: const Offset(0, -3.8),
    ).chain(CurveTween(curve: Curves.easeInCubic)).animate(_controller);

    // Brand text fades in at the bottom once the wrench has cleared the
    // top, then the typewriter within the text runs to completion.
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 0.92, curve: Curves.easeOut),
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
    context.go(role == UserRole.admin ? '/admin/shell' : '/student/shell');
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
          // Typewriter for the brand text: starts at 0.72, finishes at 0.95.
          final typingProgress =
              ((_controller.value - 0.72) / 0.23).clamp(0.0, 1.0);
          final typedLength = (_appName.length * typingProgress).floor();
          final typedName = _appName.substring(0, typedLength);
          final isTyping = typedLength < _appName.length;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Wrench: sits at center, then shoots upward.
              Align(
                alignment: Alignment.center,
                child: FractionalTranslation(
                  translation: _wrenchOffset.value,
                  child: Opacity(
                    opacity: _wrenchOpacity.value,
                    child: Transform.scale(
                      scale: _wrenchScale.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x4DFFB800),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: LaunchWrenchIcon(size: _wrenchSize),
                      ),
                    ),
                  ),
                ),
              ),
              // Brand wordmark at the bottom — where the wrench launched from.
              Align(
                alignment: const Alignment(0, 0.86),
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: typedName),
                        if (isTyping)
                          const TextSpan(
                            text: '|',
                            style: TextStyle(color: PupColors.cyberAmber),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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
