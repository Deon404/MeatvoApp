import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds compact, pin-style map markers (Zomato/Swiggy scale).
class MapMarkerHelper {
  static Future<BitmapDescriptor> storePin() => _pinMarker(
        icon: Icons.storefront_rounded,
        headColor: const Color(0xFFB31217),
        ringColor: Colors.white,
      );

  static Future<BitmapDescriptor> homePin() => _pinMarker(
        icon: Icons.home_rounded,
        headColor: const Color(0xFF2563EB),
        ringColor: Colors.white,
      );

  /// Circular scooter marker for delivery partner (inspired by Swiggy/Zomato).
  static Future<BitmapDescriptor> riderPin() async {
    const size = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final radius = size / 2.4;

    // Outer shadow circle
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Main green circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF059669),
    );

    // White ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Inner white circle for icon background
    canvas.drawCircle(
      center,
      radius * 0.68,
      Paint()..color = Colors.white,
    );

    // Scooter icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.two_wheeler.codePoint),
      style: TextStyle(
        fontSize: radius * 0.95,
        fontFamily: Icons.two_wheeler.fontFamily,
        color: const Color(0xFF059669),
        fontWeight: FontWeight.w500,
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

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.ceil(), size.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _pinMarker({
    required IconData icon,
    required Color headColor,
    required Color ringColor,
    double width = 34,
    double height = 44,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final w = width;
    final h = height;
    final headRadius = w * 0.36;
    final headCenter = Offset(w / 2, headRadius + 3);

    // Soft ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - 2),
        width: w * 0.55,
        height: 5,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // Pin body (teardrop)
    final pinPath = Path()
      ..moveTo(w / 2, h - 1)
      ..quadraticBezierTo(w * 0.12, headRadius * 1.4, headCenter.dx - headRadius, headCenter.dy)
      ..arcToPoint(
        Offset(headCenter.dx + headRadius, headCenter.dy),
        radius: Radius.circular(headRadius),
        clockwise: true,
      )
      ..quadraticBezierTo(w * 0.88, headRadius * 1.4, w / 2, h - 1)
      ..close();

    canvas.drawShadow(pinPath, Colors.black.withValues(alpha: 0.35), 3, false);
    canvas.drawPath(pinPath, Paint()..color = headColor);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = ringColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner white circle for icon
    canvas.drawCircle(
      headCenter,
      headRadius * 0.72,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: headRadius * 0.95,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: headColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        headCenter.dx - textPainter.width / 2,
        headCenter.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.ceil(), h.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
