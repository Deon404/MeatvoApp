import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_constants.dart';

/// Premium, high-DPI map markers for live order tracking (store, home, rider).
class MapMarkerHelper {
  static const double _pixelRatio = 3.0;

  static Future<BitmapDescriptor> storePin() => _locationPin(
        icon: Icons.storefront_rounded,
        gradient: const [
          Color(0xFFFF5A71),
          AppColors.primary,
          Color(0xFF8E0B24),
        ],
        iconColor: AppColors.primary,
        accentColor: AppColors.primary,
        logicalWidth: 52,
        logicalHeight: 68,
      );

  static Future<BitmapDescriptor> homePin() => _locationPin(
        icon: Icons.home_rounded,
        gradient: const [
          Color(0xFF93C5FD),
          Color(0xFF3B82F6),
          Color(0xFF1E40AF),
        ],
        iconColor: const Color(0xFF2563EB),
        accentColor: const Color(0xFF3B82F6),
        logicalWidth: 52,
        logicalHeight: 68,
      );

  /// Directional rider badge — rotates with bearing when [Marker.flat] is true.
  static Future<BitmapDescriptor> riderPin() => _riderBadge(
        logicalSize: 56,
      );

  static Future<BitmapDescriptor> _locationPin({
    required IconData icon,
    required List<Color> gradient,
    required Color iconColor,
    required Color accentColor,
    required double logicalWidth,
    required double logicalHeight,
  }) async {
    return _renderBitmap(
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      painter: (canvas, w, h) {
        final headRadius = w * 0.36;
        final headCenter = Offset(w / 2, headRadius + 6);
        final tip = Offset(w / 2, h - 2);

        // Ground shadow
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h - 1),
            width: w * 0.44,
            height: 7,
          ),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        // Pin body
        final pinPath = _buildPinPath(
          headCenter: headCenter,
          headRadius: headRadius,
          tip: tip,
        );

        canvas.drawShadow(
          pinPath,
          Colors.black.withValues(alpha: 0.28),
          5,
          false,
        );

        canvas.drawPath(
          pinPath,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(headCenter.dx, headCenter.dy - headRadius),
              Offset(headCenter.dx, tip.dy),
              gradient,
              [0.0, 0.45, 1.0],
            ),
        );

        // Specular highlight on the pin head
        canvas.drawArc(
          Rect.fromCircle(center: headCenter, radius: headRadius * 0.88),
          -2.6,
          1.4,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.42)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );

        // Crisp outer ring
        canvas.drawPath(
          pinPath,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );

        // Inner badge disc
        canvas.drawCircle(
          headCenter,
          headRadius * 0.72,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          headCenter,
          headRadius * 0.72,
          Paint()
            ..color = accentColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );

        _paintIcon(
          canvas,
          icon,
          headCenter,
          headRadius * 0.56,
          iconColor,
        );
      },
    );
  }

  static Future<BitmapDescriptor> _riderBadge({
    required double logicalSize,
  }) async {
    return _renderBitmap(
      logicalWidth: logicalSize,
      logicalHeight: logicalSize,
      painter: (canvas, size, _) {
        final center = Offset(size / 2, size / 2);
        const radius = 22.0;

        // Single soft shadow — no stacked glow rings
        canvas.drawCircle(
          center.translate(0, 2.5),
          radius + 1,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );

        // Direction wedge (points north; rotates with marker bearing)
        final wedgePath = Path()
          ..moveTo(center.dx, center.dy - radius - 1)
          ..lineTo(center.dx - 7.5, center.dy - radius + 9)
          ..lineTo(center.dx + 7.5, center.dy - radius + 9)
          ..close();
        canvas.drawPath(
          wedgePath,
          Paint()..color = Colors.white,
        );
        canvas.drawPath(
          wedgePath,
          Paint()
            ..color = const Color(0xFF047857)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );

        // Main badge
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = ui.Gradient.radial(
              center.translate(-4, -4),
              radius * 1.15,
              const [
                Color(0xFF6EE7B7),
                AppColors.success,
                Color(0xFF059669),
                Color(0xFF047857),
              ],
              [0.0, 0.35, 0.72, 1.0],
            ),
        );

        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );

        // Inner disc for icon contrast
        canvas.drawCircle(
          center,
          radius * 0.68,
          Paint()..color = Colors.white.withValues(alpha: 0.96),
        );

        _paintIcon(
          canvas,
          Icons.two_wheeler_rounded,
          center,
          radius * 0.52,
          const Color(0xFF047857),
        );

        // Live indicator dot
        final liveCenter = Offset(center.dx + radius * 0.62, center.dy - radius * 0.62);
        canvas.drawCircle(
          liveCenter,
          5.5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          liveCenter,
          4,
          Paint()..color = AppColors.primary,
        );
      },
    );
  }

  static Path _buildPinPath({
    required Offset headCenter,
    required double headRadius,
    required Offset tip,
  }) {
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        tip.dx - headRadius * 0.35,
        headCenter.dy + headRadius * 0.55,
        headCenter.dx - headRadius,
        headCenter.dy,
      )
      ..arcToPoint(
        Offset(headCenter.dx + headRadius, headCenter.dy),
        radius: Radius.circular(headRadius),
        clockwise: true,
      )
      ..quadraticBezierTo(
        tip.dx + headRadius * 0.35,
        headCenter.dy + headRadius * 0.55,
        tip.dx,
        tip.dy,
      )
      ..close();
  }

  static Future<BitmapDescriptor> _renderBitmap({
    required double logicalWidth,
    required double logicalHeight,
    required void Function(Canvas canvas, double w, double h) painter,
  }) async {
    final pixelWidth = (logicalWidth * _pixelRatio).ceil();
    final pixelHeight = (logicalHeight * _pixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_pixelRatio);
    painter(canvas, logicalWidth, logicalHeight);

    final picture = recorder.endRecording();
    final image = await picture.toImage(pixelWidth, pixelHeight);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: logicalWidth,
      height: logicalHeight,
    );
  }

  static void _paintIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }
}
