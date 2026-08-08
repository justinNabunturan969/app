import 'package:flutter/material.dart';

/// Wrench glyph for the launch loader.
///
/// The shape comes from the RemixIcon "wrench-fill" glyph, originally an
/// SVG path. We render it with a [CustomPainter] instead of an SVG asset
/// to avoid the render quirks [flutter_svg] has shown with the
/// background placeholder path and the `ColorFilter.mode(srcIn)` we apply
/// for theming. A direct `Path` paints exactly what the path data says,
/// every time, on every device.
class WrenchIcon extends StatelessWidget {
  const WrenchIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WrenchPainter(color: color),
      ),
    );
  }
}

class _WrenchPainter extends CustomPainter {
  _WrenchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The original SVG viewBox is 24x24; scale the path up to whatever
    // box the widget is given so the stroke widths and corners stay
    // proportional at any rendered size.
    final scale = size.shortestSide / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(_buildPath(), paint);
    canvas.restore();
  }

  /// Direct translation of the RemixIcon wrench path
  /// (M19.249 6.872 a1 1 0 0 1 1.645.36 ...). Each relative `a`/`l`
  /// is resolved to its absolute target and then expressed in Flutter's
  /// [Path] API.
  static Path _buildPath() {
    return Path()
      ..moveTo(19.249, 6.872)
      // a 1 1 0 0 1 1.645 .36  -> (20.894, 7.232)
      ..arcToPoint(
        const Offset(20.894, 7.232),
        radius: const Radius.circular(1),
        largeArc: false,
        clockwise: true,
      )
      // a 7.001 7.001 0 0 1 -8.912 9.037  -> (11.982, 16.269)
      ..arcToPoint(
        const Offset(11.982, 16.269),
        radius: const Radius.circular(7.001),
        largeArc: false,
        clockwise: true,
      )
      // l -4.013 4.013  -> (7.969, 20.282)
      ..lineTo(7.969, 20.282)
      // a 3 3 0 1 1 -4.243 -4.243  -> (3.726, 16.039)
      ..arcToPoint(
        const Offset(3.726, 16.039),
        radius: const Radius.circular(3),
        largeArc: true,
        clockwise: true,
      )
      // l 4.013 -4.013  -> (7.739, 12.026)
      ..lineTo(7.739, 12.026)
      // a 7 7 0 0 1 9.025 -8.917  -> (16.764, 3.109)
      ..arcToPoint(
        const Offset(16.764, 3.109),
        radius: const Radius.circular(7),
        largeArc: false,
        clockwise: true,
      )
      // a 1 1 0 0 1 .36 1.645  -> (17.124, 4.754)
      ..arcToPoint(
        const Offset(17.124, 4.754),
        radius: const Radius.circular(1),
        largeArc: false,
        clockwise: true,
      )
      // L 14.768 7.11
      ..lineTo(14.768, 7.11)
      // a 1.5 1.5 0 0 0 2.121 2.122  -> (16.889, 9.232)
      ..arcToPoint(
        const Offset(16.889, 9.232),
        radius: const Radius.elliptical(1.5, 1.5),
        largeArc: false,
        clockwise: false,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_WrenchPainter oldDelegate) =>
      oldDelegate.color != color;
}
