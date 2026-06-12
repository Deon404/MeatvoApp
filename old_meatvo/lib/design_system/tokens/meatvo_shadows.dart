import 'package:flutter/material.dart';

abstract final class MeatvoShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A1A1210),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x121A1210),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x181A1210),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];

  /// Elevated product card — soft, trustworthy depth.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F1A1210),
      blurRadius: 28,
      spreadRadius: -4,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x081A1210),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}
