import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../tokens/meatvo_colors.dart';
import '../tokens/meatvo_radii.dart';
import '../tokens/meatvo_spacing.dart';
import 'meatvo_theme_extensions.dart';

/// Premium Meatvo theme — extends existing AppTheme with warm commerce palette.
abstract final class MeatvoTheme {
  static ThemeData get light {
    final base = AppTheme.lightTheme;
    final textTheme = _buildTextTheme(
      primaryColor: MeatvoColors.textPrimary,
      secondaryColor: MeatvoColors.textSecondary,
      mutedColor: MeatvoColors.textMuted,
    );

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: MeatvoColors.brandPrimary,
      onPrimary: MeatvoColors.white,
      secondary: MeatvoColors.freshBadge,
      onSecondary: MeatvoColors.white,
      error: MeatvoColors.error,
      onError: MeatvoColors.white,
      surface: MeatvoColors.surfaceCard,
      onSurface: MeatvoColors.textPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MeatvoColors.surfaceWarm,
      canvasColor: MeatvoColors.surfaceWarm,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: const [MeatvoThemeData.light],
      appBarTheme: AppBarTheme(
        backgroundColor: MeatvoColors.surfaceCard,
        foregroundColor: MeatvoColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(
          color: MeatvoColors.textPrimary,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: MeatvoColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeatvoRadii.lg),
          side: const BorderSide(color: MeatvoColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MeatvoColors.surfaceCard,
        selectedColor: MeatvoColors.brandPrimary,
        labelStyle: textTheme.labelMedium ?? const TextStyle(),
        secondaryLabelStyle: (textTheme.labelMedium ?? const TextStyle())
            .copyWith(color: MeatvoColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeatvoRadii.pill),
          side: const BorderSide(color: MeatvoColors.border),
        ),
        side: const BorderSide(color: MeatvoColors.border),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MeatvoColors.brandPrimary,
          foregroundColor: MeatvoColors.white,
          minimumSize: const Size.fromHeight(48),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeatvoRadii.pill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MeatvoColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MeatvoSpacing.md,
          vertical: MeatvoSpacing.sm,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: MeatvoColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeatvoRadii.md),
          borderSide: const BorderSide(color: MeatvoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeatvoRadii.md),
          borderSide: const BorderSide(
            color: MeatvoColors.brandPrimary,
            width: 1.4,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MeatvoColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MeatvoRadii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MeatvoColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: MeatvoColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeatvoRadii.md),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Color primaryColor,
    required Color secondaryColor,
    required Color mutedColor,
  }) {
    TextStyle poppins({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.25,
    }) {
      return GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );
    }

    return TextTheme(
      displayLarge: poppins(size: 28, weight: FontWeight.w700, color: primaryColor),
      displayMedium: poppins(size: 24, weight: FontWeight.w700, color: primaryColor),
      displaySmall: poppins(size: 22, weight: FontWeight.w700, color: primaryColor),
      headlineLarge: poppins(size: 22, weight: FontWeight.w700, color: primaryColor),
      headlineMedium: poppins(size: 20, weight: FontWeight.w700, color: primaryColor),
      headlineSmall: poppins(size: 18, weight: FontWeight.w700, color: primaryColor),
      titleLarge: poppins(size: 18, weight: FontWeight.w600, color: primaryColor),
      titleMedium: poppins(size: 16, weight: FontWeight.w600, color: primaryColor),
      titleSmall: poppins(size: 14, weight: FontWeight.w600, color: primaryColor),
      bodyLarge: poppins(size: 15, weight: FontWeight.w400, color: primaryColor, height: 1.45),
      bodyMedium: poppins(size: 14, weight: FontWeight.w400, color: secondaryColor, height: 1.45),
      bodySmall: poppins(size: 12, weight: FontWeight.w400, color: mutedColor, height: 1.4),
      labelLarge: poppins(size: 14, weight: FontWeight.w600, color: primaryColor),
      labelMedium: poppins(size: 12, weight: FontWeight.w600, color: secondaryColor),
      labelSmall: poppins(size: 11, weight: FontWeight.w500, color: mutedColor),
    );
  }
}
