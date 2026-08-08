import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Crisp vector wrench used on the launch loader.
///
/// Draws the classic open-end spanner silhouette (Material "build" glyph)
/// with a CustomPainter so rendering never depends on the icon font.
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

  static const _viewBox = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    final dx = (size.width - _viewBox * scale) / 2;
    final dy = (size.height - _viewBox * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final wrench = _wrenchPath();
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
        ..strokeWidth = 0.6
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    canvas.restore();
  }

  /// Open-end spanner path from the Material "build" icon (24x24 viewBox).
  Path _wrenchPath() {
    return Path()
      ..moveTo(22.7, 19.0)
      ..lineTo(13.6, 9.9)
      ..cubicTo(14.5, 7.6, 14.0, 4.9, 12.1, 3.0)
      ..cubicTo(10.1, 1.0, 7.1, 0.6, 4.7, 1.8)
      ..lineTo(9.0, 6.0)
      ..lineTo(6.0, 9.0)
      ..lineTo(1.6, 4.7)
      ..cubicTo(0.4, 7.1, 0.9, 10.1, 2.9, 12.1)
      ..cubicTo(4.8, 14.0, 7.5, 14.5, 9.8, 13.6)
      ..lineTo(18.9, 22.7)
      ..cubicTo(19.3, 23.1, 19.9, 23.1, 20.3, 22.7)
      ..lineTo(22.6, 20.4)
      ..cubicTo(23.1, 20.0, 23.1, 19.3, 22.7, 19.0)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _LaunchWrenchPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
