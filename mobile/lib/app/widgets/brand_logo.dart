import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The 3-leaf seedling mark representing Astawash.
class AstawashBrandLogo extends StatelessWidget {
  const AstawashBrandLogo({
    super.key,
    this.size = 64,
    this.color = AppColors.sand,
    this.showBadgeBackground = false,
  });

  final double size;
  final Color color;
  final bool showBadgeBackground;

  @override
  Widget build(BuildContext context) {
    final logo = CustomPaint(
      size: Size(size, size),
      painter: _SeedlingPainter(color: color),
    );

    if (!showBadgeBackground) {
      return logo;
    }

    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: logo,
    );
  }
}

class _SeedlingPainter extends CustomPainter {
  const _SeedlingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Draw central upright leaf
    final centerLeaf = Path();
    centerLeaf.moveTo(w * 0.5, h * 0.85);
    centerLeaf.cubicTo(
      w * 0.35,
      h * 0.55,
      w * 0.38,
      h * 0.20,
      w * 0.5,
      h * 0.08,
    );
    centerLeaf.cubicTo(
      w * 0.62,
      h * 0.20,
      w * 0.65,
      h * 0.55,
      w * 0.5,
      h * 0.85,
    );
    centerLeaf.close();
    canvas.drawPath(centerLeaf, paint);

    // Draw left leaf
    final leftLeaf = Path();
    leftLeaf.moveTo(w * 0.48, h * 0.78);
    leftLeaf.cubicTo(
      w * 0.28,
      h * 0.72,
      w * 0.08,
      h * 0.55,
      w * 0.12,
      h * 0.32,
    );
    leftLeaf.cubicTo(
      w * 0.32,
      h * 0.34,
      w * 0.45,
      h * 0.55,
      w * 0.48,
      h * 0.78,
    );
    leftLeaf.close();
    canvas.drawPath(leftLeaf, paint);

    // Draw right leaf
    final rightLeaf = Path();
    rightLeaf.moveTo(w * 0.52, h * 0.78);
    rightLeaf.cubicTo(
      w * 0.72,
      h * 0.72,
      w * 0.92,
      h * 0.55,
      w * 0.88,
      h * 0.32,
    );
    rightLeaf.cubicTo(
      w * 0.68,
      h * 0.34,
      w * 0.55,
      h * 0.55,
      w * 0.52,
      h * 0.78,
    );
    rightLeaf.close();
    canvas.drawPath(rightLeaf, paint);
  }

  @override
  bool shouldRepaint(covariant _SeedlingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
