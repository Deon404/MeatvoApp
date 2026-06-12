import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Minimal modern delivery illustration — no external assets required.
class DeliveryLocationIllustration extends StatelessWidget {
  const DeliveryLocationIllustration({
    super.key,
    this.height = 220,
    this.variant = DeliveryIllustrationVariant.delivery,
    this.backgroundImagePath,
  });

  final double height;
  final DeliveryIllustrationVariant variant;
  final String? backgroundImagePath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          if (backgroundImagePath != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.68,
                  heightFactor: 0.68,
                  child: ClipOval(
                    child: Opacity(
                      opacity: 0.2,
                      child: Image.asset(
                        backgroundImagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          CustomPaint(
            painter: _DeliveryIllustrationPainter(
              variant: variant,
              hasBackgroundImage: backgroundImagePath != null,
            ),
          ),
        ],
      ),
    );
  }
}

enum DeliveryIllustrationVariant { delivery, permission }

class _DeliveryIllustrationPainter extends CustomPainter {
  _DeliveryIllustrationPainter({
    required this.variant,
    this.hasBackgroundImage = false,
  });

  final DeliveryIllustrationVariant variant;
  final bool hasBackgroundImage;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.82;

    // Soft backdrop circle (reduced opacity when background image is present)
    final backdrop = Paint()
      ..color = AppColors.primaryHover.withValues(
        alpha: hasBackgroundImage ? 0.25 : 0.55,
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(centerX, size.height * 0.42),
      size.width * 0.34,
      backdrop,
    );

    // Ground line
    final ground = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.12, groundY),
      Offset(size.width * 0.88, groundY),
      ground,
    );

    // House
    final houseLeft = centerX - size.width * 0.22;
    final houseTop = groundY - size.height * 0.28;
    final houseW = size.width * 0.28;
    final houseH = size.height * 0.22;

    final houseBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(houseLeft, houseTop + houseH * 0.22, houseW, houseH * 0.78),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      houseBody,
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      houseBody,
      Paint()
        ..color = AppColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

  // Roof
    final roof = Path()
      ..moveTo(houseLeft - 8, houseTop + houseH * 0.24)
      ..lineTo(houseLeft + houseW / 2, houseTop)
      ..lineTo(houseLeft + houseW + 8, houseTop + houseH * 0.24)
      ..close();
    canvas.drawPath(roof, Paint()..color = AppColors.primary.withValues(alpha: 0.85));

    // Door
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          houseLeft + houseW * 0.38,
          houseTop + houseH * 0.52,
          houseW * 0.24,
          houseH * 0.48,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.surface,
    );

    // Location pin
    final pinX = centerX + size.width * 0.18;
    final pinY = groundY - size.height * 0.34;
    _drawLocationPin(canvas, Offset(pinX, pinY), size.width * 0.09);

    // Delivery bag
    final bagX = centerX - size.width * 0.04;
    final bagY = groundY - size.height * 0.12;
    _drawDeliveryBag(canvas, Offset(bagX, bagY), size.width * 0.11);

    if (variant == DeliveryIllustrationVariant.permission) {
      // Shield accent for trust
      _drawShield(
        canvas,
        Offset(centerX + size.width * 0.02, size.height * 0.18),
        size.width * 0.08,
      );
    }

    // Subtle path dots
    final dotPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.35);
    for (var i = 0; i < 4; i++) {
      final t = i / 3.0;
      final dx = houseLeft + houseW + (pinX - houseLeft - houseW) * t;
      final dy = groundY - 18 - (pinY - groundY + 18).abs() * 0.3 * (1 - (t - 0.5).abs() * 2);
      canvas.drawCircle(Offset(dx, dy), 3.5, dotPaint);
    }
  }

  void _drawLocationPin(Canvas canvas, Offset center, double radius) {
    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(center.dx, center.dy - radius * 0.3), radius: radius))
      ..moveTo(center.dx - radius * 0.55, center.dy - radius * 0.1)
      ..lineTo(center.dx, center.dy + radius * 1.4)
      ..lineTo(center.dx + radius * 0.55, center.dy - radius * 0.1)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.3),
      radius * 0.38,
      Paint()..color = Colors.white,
    );
  }

  void _drawDeliveryBag(Canvas canvas, Offset topLeft, double size) {
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, size, size * 0.85),
      Radius.circular(size * 0.18),
    );
    canvas.drawRRect(bag, Paint()..color = AppColors.success.withValues(alpha: 0.9));
    canvas.drawRRect(
      bag,
      Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Handle
    final handle = Path()
      ..moveTo(topLeft.dx + size * 0.25, topLeft.dy)
      ..quadraticBezierTo(
        topLeft.dx + size * 0.5,
        topLeft.dy - size * 0.22,
        topLeft.dx + size * 0.75,
        topLeft.dy,
      );
    canvas.drawPath(
      handle,
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawShield(Canvas canvas, Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.85, center.dy - size * 0.55)
      ..lineTo(center.dx + size * 0.85, center.dy + size * 0.15)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size * 0.95,
        center.dx - size * 0.85,
        center.dy + size * 0.15,
      )
      ..lineTo(center.dx - size * 0.85, center.dy - size * 0.55)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      center,
      size * 0.22,
      Paint()..color = AppColors.primary.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant _DeliveryIllustrationPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.hasBackgroundImage != hasBackgroundImage;
}
