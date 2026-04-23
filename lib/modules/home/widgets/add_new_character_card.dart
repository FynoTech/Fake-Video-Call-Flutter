import 'package:flutter/material.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_colors.dart';

/// Dashed-border pill card prompting the user to create a custom prank.
///
/// Matches the "Add New Character" mockup: rounded pill with dashed
/// outline, a soft-green gradient circle on the left holding a large
/// "+" icon, and a two-line text block (title + muted subtitle) on the
/// right.
class AddNewCharacterCard extends StatelessWidget {
  const AddNewCharacterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: const Color(0xFFBDBDBD),
            radius: 99,
            dashLength: 6,
            gapLength: 5,
            strokeWidth: 1.3,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  AppAssets.icAddNew,
                  width: 40,
                  height: 40,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.add_rounded,
                    size: 28,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFBFBFBF),
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed stroke along a rounded-rectangle border.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength, gapLength);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, double dash, double gap) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        result.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength ||
      old.strokeWidth != strokeWidth;
}
