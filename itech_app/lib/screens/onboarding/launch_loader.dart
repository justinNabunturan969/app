import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session/auth_session_storage.dart';
import '../../main.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/launch_wrench_icon.dart';

/// The app's universal entry animation.
///
/// The wrench rises from below the screen, settles in the center, glides left,
/// and reveals the product name with a typewriter effect before navigation.
class LaunchLoader extends StatefulWidget {
  const LaunchLoader({super.key});

  @override
  State<LaunchLoader> createState() => _LaunchLoaderState();
}

class _LaunchLoaderState extends State<LaunchLoader>
    with SingleTickerProviderStateMixin {
  static const _appName = 'ITech App';
  static const _wrenchSize = 86.0;

  late final AnimationController _controller;
  late final Animation<Alignment> _wrenchAlignment;
  late final Animation<double> _wrenchScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _wrenchAlignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: const Alignment(0, 2.15),
          end: Alignment.center,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: Alignment.center,
          end: const Alignment(-0.42, 0),
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Alignment>(const Alignment(-0.42, 0)),
        weight: 36,
      ),
    ]).animate(_controller);
    _wrenchScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.72,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
    ]).animate(_controller);
    _runAndAdvance();
  }

  Future<void> _runAndAdvance() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 240));
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
          final typingProgress = ((_controller.value - 0.64) / 0.27).clamp(
            0.0,
            1.0,
          );
          final typedLength = (_appName.length * typingProgress).floor();
          final typedName = _appName.substring(0, typedLength);
          final isTyping = typedLength < _appName.length;

          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: _wrenchAlignment.value,
                child: Transform.scale(
                  scale: _wrenchScale.value,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x4DFFB800),
                          blurRadius: 28,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: LaunchWrenchIcon(size: _wrenchSize),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0.28, 0),
                child: Opacity(
                  opacity: typingProgress,
                  child: SizedBox(
                    width: 168,
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
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                      ),
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
