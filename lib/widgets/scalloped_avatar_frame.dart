import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';

/// iOS-style “flower” ring: circular photo with a scalloped outer border.
class ScallopedAvatarFrame extends StatelessWidget {
  const ScallopedAvatarFrame({
    super.key,
    required this.innerDiameter,
    required this.child,
    this.ringColor = AppColors.white,
    this.ringBaseWidth = 5,
    this.scallopDepth = 2.4,
    this.lobes = 14,
  });

  /// Diameter of the circular face (image) inside the scalloped ring.
  final double innerDiameter;
  final Widget child;
  final Color ringColor;

  /// Average radial thickness of the ring before scallop modulation.
  final double ringBaseWidth;

  /// Extra radius added/subtracted by the cosine wave (keep below [ringBaseWidth]).
  final double scallopDepth;

  final int lobes;

  double get _outerExtent =>
      innerDiameter / 2 + ringBaseWidth + scallopDepth;

  double get totalDiameter => _outerExtent * 2;

  @override
  Widget build(BuildContext context) {
    final innerR = innerDiameter / 2;
    return SizedBox(
      width: totalDiameter,
      height: totalDiameter,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(totalDiameter, totalDiameter),
            painter: _ScallopedRingPainter(
              center: Offset(_outerExtent, _outerExtent),
              innerRadius: innerR,
              meanExtra: ringBaseWidth,
              scallopDepth: scallopDepth,
              lobes: lobes,
              color: ringColor,
            ),
          ),
          SizedBox(
            width: innerDiameter,
            height: innerDiameter,
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }
}

class _ScallopedRingPainter extends CustomPainter {
  _ScallopedRingPainter({
    required this.center,
    required this.innerRadius,
    required this.meanExtra,
    required this.scallopDepth,
    required this.lobes,
    required this.color,
  });

  final Offset center;
  final double innerRadius;
  final double meanExtra;
  final double scallopDepth;
  final int lobes;
  final Color color;

  Path _outerScallopedPath() {
    const segments = 180;
    final path = Path();
    final meanR = innerRadius + meanExtra;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments * 2 * math.pi;
      final r = meanR + scallopDepth * math.cos(lobes * t);
      final x = center.dx + r * math.cos(t);
      final y = center.dy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _outerScallopedPath();
    final inner = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    final ring = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      ring,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _ScallopedRingPainter oldDelegate) {
    return oldDelegate.innerRadius != innerRadius ||
        oldDelegate.meanExtra != meanExtra ||
        oldDelegate.scallopDepth != scallopDepth ||
        oldDelegate.lobes != lobes ||
        oldDelegate.color != color ||
        oldDelegate.center != center;
  }
}
