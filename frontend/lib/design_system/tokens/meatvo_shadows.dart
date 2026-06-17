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

  /// Claymorphism embossed — light highlight top-left, soft shadow bottom-right.
  static const List<BoxShadow> clay = [
    BoxShadow(
      color: Color(0x66FFFFFF),
      offset: Offset(-6, -6),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x181A1210),
      offset: Offset(8, 8),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  /// Claymorphism pressed/inset — reversed light direction.
  static const List<BoxShadow> clayInset = [
    BoxShadow(
      color: Color(0x141A1210),
      offset: Offset(4, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x40FFFFFF),
      offset: Offset(-3, -3),
      blurRadius: 10,
      spreadRadius: -2,
    ),
  ];
}
