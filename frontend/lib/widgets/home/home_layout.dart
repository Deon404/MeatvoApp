import 'package:flutter/material.dart';

/// Shared layout tokens for the home screen (Blinkit / Licious style).
abstract final class HomeLayout {
  static const Color background = Color(0xFFF8F8F8);

  static const double horizontalPadding = 16;
  static const double sectionGap = 24;

  static const double bannerHeight = 140;
  static const double bannerRadius = 16;

  static const int categoryCrossAxisCount = 2;
  static const double categoryAspectRatio = 1.1;
  static const double categorySpacing = 12;
  static const int maxHomeCategories = 4;

  static const double featuredCardWidth = 160;
  static const double featuredListHeight = 240;

  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1A1A1A),
  );
}
