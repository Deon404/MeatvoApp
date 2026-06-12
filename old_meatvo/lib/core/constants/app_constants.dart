import 'package:flutter/material.dart';

class AppColors {
  // Light theme backgrounds
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  
  // Brand colors
  static const primary = Color(0xFFC8102E);
  static const primaryHover = Color(0xFFC41E3A);
  static const primaryLight = Color(0xFFFFE8EA);
  static const redPrimary = Color(0xFFC8102E);
  
  // Text colors (dark on light)
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  
  // Status colors
  static const success = Color(0xFF10B981);
  static const freshBadge = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const bluePrimary = Color(0xFF3B82F6);
  
  // UI elements
  static const divider = Color(0xFFE5E7EB);
  static const borderDefault = Color(0xFFD1D5DB);
  
  // Gray scale
  static const greyLight = Color(0xFFF3F4F6);
  static const greyMedium = Color(0xFF9CA3AF);
  
  // Basic colors
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  
  // Surface variations
  static const surfaceWarm = Color(0xFFFAFAFA);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F6);

  // Shared design tokens (single source of truth for screens)
  static const warmBg = Color(0xFFFAF9F7);
  static const cardBg = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1A1A1A);
  static const textMedium = Color(0xFF6B6B6B);
  static const accentLight = Color(0xFFFCEBEB);
  static const border = Color(0xFFEEEEEE);
}

class AppTextStyles {
  // All use Poppins font
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
    letterSpacing: -0.5,
  );
  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
    letterSpacing: -0.3,
  );
  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    fontFamily: 'Poppins',
    height: 1.5,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    fontFamily: 'Poppins',
  );
  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    fontFamily: 'Poppins',
    letterSpacing: 0.5,
  );
}

class AppSpacing {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

class AppRadius {
  static const double card = 16, button = 12, chip = 20, image = 12;
}
