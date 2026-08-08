import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';

/// Branded entry sequence: mark rises into the center, slides left, and the
/// app name types in before the welcome page is shown.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _appName = 'ITech App';

  late final AnimationController _controller;
  late final Animation<Alignment> _markAlignment;
  late final Animation<double> _markScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _markAlignment = TweenSequence<Alignment>([
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
    _markScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.72,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
    ]).animate(_controller);
    _playIntro();
  }

  Future<void> _playIntro() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 240));
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
                alignment: _markAlignment.value,
                child: Transform.scale(
                  scale: _markScale.value,
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        PupColors.cyberAmber,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/branding/pup_itech_source_icon.png',
                      ),
                    ),
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
