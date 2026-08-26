import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session/auth_session_storage.dart';
import '../../main.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/launch_wrench_icon.dart';

/// The app's universal entry animation.
///
/// The wrench rises exactly through the visual center, glides to its final
/// wordmark position, then reveals the app name with a typewriter effect.
class LaunchLoader extends StatefulWidget {
  const LaunchLoader({super.key});

  @override
  State<LaunchLoader> createState() => _LaunchLoaderState();
}

class _LaunchLoaderState extends State<LaunchLoader>
    with SingleTickerProviderStateMixin {
  static const _appName = 'ITech App';
  static const _wrenchSize = 82.0;
  static const _wordmarkWidth = 145.0;
  static const _gap = 10.0;

  late final AnimationController _controller;
  late final Animation<double> _wrenchScale;

  /// Captured in [didChangeDependencies] BEFORE any async gap: reading
  /// `GoRouterState.of(context)` after an `await` is unsafe (the element
  /// may have been deactivated mid-animation).
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
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
    // NOTE: the kick flag is captured in [didChangeDependencies], which
    // always runs right after [initState] — `GoRouterState.of(context)`
    // may not be called this early.
    _runAndAdvance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also re-capture if the route updates while the animation is running
    // (e.g. the kick handler navigates here mid-boot).
    _captureKickFlag();
  }

  void _captureKickFlag() {
    _kicked =
        GoRouterState.of(context).uri.queryParameters['kicked'] == '1' ||
        _kicked;
  }

  Future<void> _runAndAdvance() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    // Forced-logout replay: an administrator kicked this device, so the
    // "reload" lands on the login screen where the admin's reason is
    // shown (read from prefs by StudentLoginScreen).
    if (_kicked) {
      context.go('/student/login?kicked=1');
      return;
    }

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

  /// Converts a horizontal pixel offset from screen center into an
  /// [Alignment] coordinate for a child of [childWidth]. This keeps the
  /// completed icon + wordmark lockup centered at every viewport width.
  double _alignmentForOffset({
    required double screenWidth,
    required double childWidth,
    required double offset,
  }) {
    final availableTravel = (screenWidth - childWidth) / 2;
    if (availableTravel <= 0) return 0;
    return (offset / availableTravel).clamp(-1.0, 1.0);
  }

  Alignment _wrenchAlignment({
    required double progress,
    required double finalX,
  }) {
    if (progress <= 0.40) {
      final t = Curves.easeOutBack.transform(progress / 0.40);
      return Alignment.lerp(const Alignment(0, 2.15), Alignment.center, t)!;
    }
    if (progress <= 0.64) {
      final t = Curves.easeInOutCubic.transform((progress - 0.40) / 0.24);
      return Alignment.lerp(Alignment.center, Alignment(finalX, 0), t)!;
    }
    return Alignment(finalX, 0);
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Final lockup width is wrench + gap + wordmark. Its center remains
          // at screen center, placing the wrench and text at these offsets.
          final wrenchFinalOffset = -(_gap + _wordmarkWidth) / 2;
          final textFinalOffset = (_wrenchSize + _gap) / 2;
          final wrenchFinalX = _alignmentForOffset(
            screenWidth: constraints.maxWidth,
            childWidth: _wrenchSize,
            offset: wrenchFinalOffset,
          );
          final textFinalX = _alignmentForOffset(
            screenWidth: constraints.maxWidth,
            childWidth: _wordmarkWidth,
            offset: textFinalOffset,
          );

          return AnimatedBuilder(
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
                    alignment: _wrenchAlignment(
                      progress: _controller.value,
                      finalX: wrenchFinalX,
                    ),
                    child: Transform.scale(
                      scale: _wrenchScale.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33FFB800),
                              blurRadius: 36,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Color(0x22FFB800),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: LaunchWrenchIcon(size: _wrenchSize),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(textFinalX, 0),
                    child: SizedBox(
                      width: _wordmarkWidth,
                      child: Opacity(
                        opacity: typingProgress,
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
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
