import 'package:flutter/material.dart';

/// Creates a soft wave that helps hero sections blend into cards below.
class WaveClipper extends CustomClipper<Path> {
  const WaveClipper({
    this.waveHeight = 32,
    this.invert = false,
  });

  final double waveHeight;
  final bool invert;

  @override
  Path getClip(Size size) {
    final path = Path();

    if (invert) {
      path.moveTo(0, waveHeight);
      path.quadraticBezierTo(
        size.width * 0.22,
        0,
        size.width * 0.5,
        waveHeight * 0.75,
      );
      path.quadraticBezierTo(
        size.width * 0.82,
        waveHeight * 1.5,
        size.width,
        waveHeight * 0.65,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.lineTo(0, size.height - waveHeight);
      path.quadraticBezierTo(
        size.width * 0.22,
        size.height,
        size.width * 0.5,
        size.height - (waveHeight * 0.45),
      );
      path.quadraticBezierTo(
        size.width * 0.82,
        size.height - (waveHeight * 1.5),
        size.width,
        size.height - (waveHeight * 0.8),
      );
      path.lineTo(size.width, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper oldClipper) {
    return oldClipper.waveHeight != waveHeight || oldClipper.invert != invert;
  }
}
