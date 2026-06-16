import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Upgraded Custom Category Icon - Modern design with 3 food items
/// (Chicken Drumstick, Egg, Fish) stacked vertically
/// Shows variety of meat categories with improved visual design
class CategoryIcon extends StatelessWidget {
  final Color? color;
  final double size;

  const CategoryIcon({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.greyMedium;
    final iconSize = size;

    return SizedBox(
      width: iconSize,
      height: iconSize * 1.3,
      child: CustomPaint(
        painter: CategoryIconPainter(
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}

/// Upgraded Custom Painter for Category Icons (Chicken, Egg, Fish)
/// Modern, clean design with improved proportions and visual appeal
class CategoryIconPainter extends CustomPainter {
  final Color color;
  final double size;

  CategoryIconPainter({
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Improved paint settings for better rendering
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Better proportions for 3 icons stacked
    final itemHeight = canvasSize.height / 3.8;
    final itemWidth = canvasSize.width * 0.85;
    final spacing = itemHeight * 0.25;
    final startX = (canvasSize.width - itemWidth) / 2;

    // 1. Chicken Drumstick (Top) - Improved design
    _drawChickenDrumstick(
      canvas,
      Offset(startX, spacing),
      itemWidth,
      itemHeight,
      fillPaint,
      outlinePaint,
    );

    // 2. Egg (Middle) - Better positioning
    _drawEgg(
      canvas,
      Offset(startX, spacing + itemHeight + spacing * 0.4),
      itemWidth,
      itemHeight * 0.85,
      fillPaint,
      outlinePaint,
    );

    // 3. Fish (Bottom) - Enhanced design
    _drawFish(
      canvas,
      Offset(startX, spacing * 2 + itemHeight * 1.85),
      itemWidth,
      itemHeight * 0.95,
      fillPaint,
      outlinePaint,
    );
  }

  /// Draw Chicken Drumstick - Upgraded with better proportions
  void _drawChickenDrumstick(
    Canvas canvas,
    Offset position,
    double width,
    double height,
    Paint paint,
    Paint outlinePaint,
  ) {
    // Meat portion (top) - More realistic shape
    final meatPath = Path()
      ..moveTo(position.dx + width * 0.25, position.dy + height * 0.05)
      ..quadraticBezierTo(
        position.dx + width * 0.1,
        position.dy + height * 0.15,
        position.dx + width * 0.15,
        position.dy + height * 0.35,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.2,
        position.dy + height * 0.5,
        position.dx + width * 0.4,
        position.dy + height * 0.52,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.6,
        position.dy + height * 0.5,
        position.dx + width * 0.8,
        position.dy + height * 0.4,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.9,
        position.dy + height * 0.25,
        position.dx + width * 0.85,
        position.dy + height * 0.1,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.75,
        position.dy,
        position.dx + width * 0.55,
        position.dy + height * 0.03,
      )
      ..close();

    paint.color = color.withValues(alpha: 0.95);
    canvas.drawPath(meatPath, paint);
    canvas.drawPath(meatPath, outlinePaint);

    // Bone portion (bottom) - Cleaner design
    final bonePath = Path()
      ..moveTo(position.dx + width * 0.42, position.dy + height * 0.52)
      ..lineTo(position.dx + width * 0.38, position.dy + height * 0.68)
      ..quadraticBezierTo(
        position.dx + width * 0.35,
        position.dy + height * 0.82,
        position.dx + width * 0.42,
        position.dy + height * 0.96,
      )
      ..lineTo(position.dx + width * 0.58, position.dy + height * 0.96)
      ..quadraticBezierTo(
        position.dx + width * 0.65,
        position.dy + height * 0.82,
        position.dx + width * 0.62,
        position.dy + height * 0.68,
      )
      ..lineTo(position.dx + width * 0.58, position.dy + height * 0.52)
      ..close();

    paint.color = color.withValues(alpha: 0.7);
    canvas.drawPath(bonePath, paint);
    canvas.drawPath(bonePath, outlinePaint);

    // Bone joint line for detail
    final jointPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(position.dx + width * 0.38, position.dy + height * 0.68),
      Offset(position.dx + width * 0.62, position.dy + height * 0.68),
      jointPaint,
    );
  }

  /// Draw Egg - Upgraded with better shape and highlight
  void _drawEgg(
    Canvas canvas,
    Offset position,
    double width,
    double height,
    Paint paint,
    Paint outlinePaint,
  ) {
    // More realistic egg shape
    final eggPath = Path()
      ..moveTo(position.dx + width * 0.5, position.dy + height * 0.05)
      ..quadraticBezierTo(
        position.dx + width * 0.22,
        position.dy + height * 0.15,
        position.dx + width * 0.28,
        position.dy + height * 0.5,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.32,
        position.dy + height * 0.8,
        position.dx + width * 0.5,
        position.dy + height * 0.98,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.68,
        position.dy + height * 0.8,
        position.dx + width * 0.72,
        position.dy + height * 0.5,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.78,
        position.dy + height * 0.15,
        position.dx + width * 0.5,
        position.dy + height * 0.05,
      )
      ..close();

    paint.color = color.withValues(alpha: 0.95);
    canvas.drawPath(eggPath, paint);
    canvas.drawPath(eggPath, outlinePaint);

    // Enhanced egg highlight for depth
    final highlightPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(position.dx + width * 0.52, position.dy + height * 0.32),
          width: width * 0.28,
          height: height * 0.28,
        ),
      );

    paint.color = color.withValues(alpha: 0.25);
    canvas.drawPath(highlightPath, paint);
  }

  /// Draw Fish - Upgraded with better proportions and details
  void _drawFish(
    Canvas canvas,
    Offset position,
    double width,
    double height,
    Paint paint,
    Paint outlinePaint,
  ) {
    // Fish body - More streamlined shape
    final fishBodyPath = Path()
      ..moveTo(position.dx + width * 0.22, position.dy + height * 0.5)
      ..quadraticBezierTo(
        position.dx + width * 0.12,
        position.dy + height * 0.28,
        position.dx + width * 0.18,
        position.dy + height * 0.08,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.32,
        position.dy + height * 0.02,
        position.dx + width * 0.5,
        position.dy + height * 0.08,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.72,
        position.dy + height * 0.12,
        position.dx + width * 0.88,
        position.dy + height * 0.42,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.92,
        position.dy + height * 0.6,
        position.dx + width * 0.88,
        position.dy + height * 0.82,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.72,
        position.dy + height * 0.92,
        position.dx + width * 0.5,
        position.dy + height * 0.88,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.32,
        position.dy + height * 0.98,
        position.dx + width * 0.18,
        position.dy + height * 0.92,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.12,
        position.dy + height * 0.72,
        position.dx + width * 0.22,
        position.dy + height * 0.5,
      )
      ..close();

    paint.color = color.withValues(alpha: 0.95);
    canvas.drawPath(fishBodyPath, paint);
    canvas.drawPath(fishBodyPath, outlinePaint);

    // Enhanced fish tail - More defined
    final tailPath = Path()
      ..moveTo(position.dx + width * 0.22, position.dy + height * 0.5)
      ..lineTo(position.dx + width * 0.02, position.dy + height * 0.28)
      ..lineTo(position.dx + width * 0.12, position.dy + height * 0.5)
      ..lineTo(position.dx + width * 0.02, position.dy + height * 0.72)
      ..close();

    paint.color = color.withValues(alpha: 0.9);
    canvas.drawPath(tailPath, paint);
    canvas.drawPath(tailPath, outlinePaint);

    // Fish fin (top) - Added detail
    final topFinPath = Path()
      ..moveTo(position.dx + width * 0.4, position.dy + height * 0.15)
      ..quadraticBezierTo(
        position.dx + width * 0.45,
        position.dy + height * 0.08,
        position.dx + width * 0.5,
        position.dy + height * 0.12,
      )
      ..quadraticBezierTo(
        position.dx + width * 0.55,
        position.dy + height * 0.08,
        position.dx + width * 0.6,
        position.dy + height * 0.15,
      )
      ..close();

    paint.color = color.withValues(alpha: 0.8);
    canvas.drawPath(topFinPath, paint);
    canvas.drawPath(topFinPath, outlinePaint);

    // Fish eye - Better positioned
    final eyePath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(position.dx + width * 0.68, position.dy + height * 0.42),
          width: width * 0.14,
          height: height * 0.18,
        ),
      );

    paint.color = color;
    canvas.drawPath(eyePath, paint);

    // Eye pupil with highlight
    final pupilPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(position.dx + width * 0.68, position.dy + height * 0.42),
          width: width * 0.07,
          height: height * 0.09,
        ),
      );

    paint.color = Colors.white;
    canvas.drawPath(pupilPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

