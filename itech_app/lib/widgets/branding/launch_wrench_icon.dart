import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Crisp vector wrench used on the launch loader.
///
/// Draws the classic open-end spanner silhouette (Material "build" glyph)
/// with a CustomPainter so rendering never depends on the icon font. The
/// finish is a machined-metal look: brand-amber body with a specular rim
/// light on the top-left edge and a soft bevel along the bottom-right.
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

    // Machined metal body: a bright roll-off at the top-left settles into
    // the brand amber core, then deepens toward the bottom-right edge.
    canvas.drawPath(
      wrench,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.36)!,
            Color.lerp(color, Colors.white, 0.10)!,
            color,
            Color.lerp(color, Colors.black, 0.26)!,
          ],
          stops: const [0.0, 0.34, 0.62, 1.0],
        ).createShader(bounds),
    );

    // Soft dark bevel hugging the lower-right silhouette for depth.
    canvas.drawPath(
      wrench,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.32),
          ],
          stops: const [0.48, 1.0],
        ).createShader(bounds),
    );

    // Specular rim light catching the upper-left edge.
    canvas.drawPath(
      wrench,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.60],
        ).createShader(bounds),
    );

    // Crisp hairline contour keeps the silhouette readable at small sizes.
    canvas.drawPath(
      wrench,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.24),
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
