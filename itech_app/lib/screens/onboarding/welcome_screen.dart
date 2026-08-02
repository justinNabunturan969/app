import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _goRole() {
    context.go('/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PupColors.pupMaroon, PupColors.deepMahogany],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Logo + glow
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: PupColors.cyberAmber.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PupColors.cyberAmber.withValues(alpha: 0.22),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseScale,
                          builder: (context, _) => Transform.scale(
                            scale: _pulseScale.value,
                            child: Icon(
                              Icons.settings_rounded,
                              size: 68,
                              color: PupColors.cyberAmber,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Innovation at Your Fingertips',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Reassurance strip — tells first-time visitors the app
                // is real and free, removes the duplicate hero line that
                // used to live here.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: PupColors.cyberAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Built for PUP-ITech students & faculty. '
                          'Free, open-source, and works offline.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Spacer(),

                _PrimaryAmberButton(label: 'Get Started', onPressed: _goRole),

                const SizedBox(height: 10),

                Center(
                  child: TextButton(
                    onPressed: () => context.go('/student/login'),
                    child: Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                        color: PupColors.techCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryAmberButton extends StatelessWidget {
  const _PrimaryAmberButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.0),
      duration: const Duration(milliseconds: 0),
      builder: (context, _, _) {
        return _PressAnimatedButton(label: label, onPressed: onPressed);
      },
    );
  }
}

class _PressAnimatedButton extends StatefulWidget {
  const _PressAnimatedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PressAnimatedButton> createState() => _PressAnimatedButtonState();
}

class _PressAnimatedButtonState extends State<_PressAnimatedButton> {
  final bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: () {
            widget.onPressed();
          },
          onLongPress: widget.onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 8,
            backgroundColor: PupColors.cyberAmber,
            foregroundColor: const Color(0xFF1B1B1B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [PupColors.cyberAmber, Colors.yellow.shade700],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
