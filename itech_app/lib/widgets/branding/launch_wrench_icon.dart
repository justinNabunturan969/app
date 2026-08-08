import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Crisp vector wrench used on the launch loader.
///
/// Replaces the raster PNG, which shipped with a baked-in checkerboard
/// background instead of real transparency.
class LaunchWrenchIcon extends StatelessWidget {
  const LaunchWrenchIcon({
    super.key,
    this.size = 124,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LaunchWrenchPainter(color: color ?? PupColors.cyberAmber),
      ),
    );
  }
}

class _LaunchWrenchPainter extends CustomPainter {
  const _LaunchWrenchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-center.dx, -center.dy);

    final wrench = _wrenchPath(size);
    final bounds = wrench.getBounds();

    canvas.drawPath(
      wrench,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.18)!,
            color,
            Color.lerp(color, Colors.black, 0.12)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );

    canvas.drawPath(
      wrench,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    canvas.restore();
  }

  Path _wrenchPath(Size size) {
    final w = size.width;
    final h = size.height;
    const r = 5.0;

    // Open-end wrench aligned diagonally inside the view box.
    return Path()
      ..moveTo(w * 0.20, h * 0.36)
      ..quadraticBezierTo(w * 0.11, h * 0.27, w * 0.20, h * 0.18)
      ..quadraticBezierTo(w * 0.28, h * 0.10, w * 0.36, h * 0.18)
      ..lineTo(w * 0.32, h * 0.22)
      ..lineTo(w * 0.38, h * 0.28)
      ..lineTo(w * 0.42, h * 0.24)
      ..lineTo(w * 0.76, h * 0.58)
      ..arcToPoint(
        Offset(w * 0.82, h * 0.66),
        radius: const Radius.circular(r),
      )
      ..lineTo(w * 0.78, h * 0.82)
      ..arcToPoint(
        Offset(w * 0.70, h * 0.86),
        radius: const Radius.circular(r),
      )
      ..lineTo(w * 0.62, h * 0.78)
      ..arcToPoint(
        Offset(w * 0.66, h * 0.70),
        radius: const Radius.circular(r),
      )
      ..lineTo(w * 0.30, h * 0.34)
      ..lineTo(w * 0.26, h * 0.38)
      ..lineTo(w * 0.20, h * 0.32)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _LaunchWrenchPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
