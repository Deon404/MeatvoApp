import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_constants.dart';
import '../design_system/tokens/meatvo_colors.dart';
import '../design_system/tokens/meatvo_spacing.dart' as mv;

class AppThemeColors {
  const AppThemeColors._();

  static const Color primary = MeatvoColors.brandPrimary;
  static const Color primaryDark = MeatvoColors.brandPrimaryDark;
  static const Color freshGreen = MeatvoColors.freshBadge;
  static const Color background = MeatvoColors.surfaceWarm;
  static const Color surface = MeatvoColors.surfaceCard;
  static const Color surface2 = MeatvoColors.surfaceMuted;
  static const Color textPrimary = MeatvoColors.textPrimary;
  static const Color textSecondary = MeatvoColors.textSecondary;
  static const Color textMuted = MeatvoColors.textMuted;
  static const Color border = MeatvoColors.border;
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF2D6A4F);
  static const Color divider = Color(0xFFF3F4F6);

  static const Color primaryLight = MeatvoColors.primaryLight;
  static const Color brandAccent = MeatvoColors.brandAccent;
  static const Color info = Color(0xFF3B82F6);
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color white = surface;
  static const Color black = Color(0xFF000000);

  static const Color chickenCategory = Color(0xFFFFD6D6);
  static const Color eggsCategory = Color(0xFFFFF0B3);
  static const Color fishCategory = Color(0xFFBBDEFB);
  static const Color muttonCategory = Color(0xFFE8D5C4);
  static const Color chickenCategoryStart = Color(0xFFFFF0F0);
  static const Color chickenCategoryEnd = Color(0xFFFFD6D6);
  static const Color eggsCategoryStart = Color(0xFFFFFBE6);
  static const Color eggsCategoryEnd = Color(0xFFFFF0B3);
  static const Color fishCategoryStart = Color(0xFFE8F4FD);
  static const Color fishCategoryEnd = Color(0xFFBBDEFB);
  static const Color muttonCategoryStart = Color(0xFFFAF0E6);
  static const Color muttonCategoryEnd = Color(0xFFE8D5C4);

  static const Color darkBackground = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkSurface2 = Color(0xFF273244);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFFD1D5DB);
  static const Color darkTextMuted = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkDivider = Color(0xFF1F2937);

  // Backward-compatible aliases for existing screens/widgets.
  static const Color textHint = textMuted;
  static const Color borderMuted = divider;
  static const Color bluePrimary = info;
  static const Color greyLight = surface2;
  static const Color greyMedium = textMuted;
  static const Color greyDark = textPrimary;
  static const Color greyText = textSecondary;
  static const Color redPrimary = primary;
  static const Color redDark = primaryDark;
  static const Color redLight = primaryLight;
  static const Color greenPrimary = freshGreen;
  static const Color greenDark = success;
  static const Color greenLight = Color(0xFFA7D6BF);
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = mv.MeatvoSpacing.xxs;
  static const double xs = mv.MeatvoSpacing.xs;
  static const double sm = mv.MeatvoSpacing.sm;
  static const double md = mv.MeatvoSpacing.md;
  static const double lg = mv.MeatvoSpacing.lg;
  static const double xl = mv.MeatvoSpacing.xl;
  static const double xxl = mv.MeatvoSpacing.xxl;
}

class AppRadius {
  const AppRadius._();

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // Backward-compatible aliases.
  static const double small = radiusSm;
  static const double medium = radiusMd;
  static const double large = radiusLg;
  static const double pill = radiusPill;
}

class AppShadows {
  const AppShadows._();

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static const List<BoxShadow> card = [cardShadow];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];
}

class AppTheme {
  const AppTheme._();

  static TextTheme get textTheme => _buildTextTheme(
        primaryColor: AppThemeColors.textPrimary,
        secondaryColor: AppThemeColors.textSecondary,
        mutedColor: AppThemeColors.textMuted,
      );

  static TextTheme get darkTextTheme => _buildTextTheme(
        primaryColor: AppThemeColors.darkTextPrimary,
        secondaryColor: AppThemeColors.darkTextSecondary,
        mutedColor: AppThemeColors.darkTextMuted,
      );

  static ThemeData get lightTheme {
    const warmBg = AppColors.warmBg;
    const brandPrimary = Color(0xFFC8102E);
    const textDark = AppColors.textDark;
    const inputBorder = Color(0xFFE5E5E5);
    const navUnselected = Color(0xFF9E9E9E);

    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: brandPrimary,
      onPrimary: AppThemeColors.white,
      secondary: AppThemeColors.freshGreen,
      onSecondary: AppThemeColors.white,
      error: AppThemeColors.error,
      onError: AppThemeColors.white,
      surface: AppThemeColors.surface,
      onSurface: textDark,
    );

    final appBarTitleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      primaryColor: brandPrimary,
      scaffoldBackgroundColor: warmBg,
      canvasColor: warmBg,
      splashColor: AppThemeColors.primary.withValues(alpha: 0.08),
      highlightColor: AppThemeColors.primary.withValues(alpha: 0.04),
      dividerColor: AppThemeColors.divider,
      shadowColor: AppShadows.cardShadow.color,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: AppThemeColors.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: warmBg,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: appBarTitleStyle,
        iconTheme: const IconThemeData(
          color: textDark,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppShadows.cardShadow.color,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppThemeColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppThemeColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.radiusXl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppThemeColors.textMuted,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppThemeColors.textSecondary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: inputBorder),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: brandPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          borderSide: const BorderSide(color: AppThemeColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          borderSide: const BorderSide(
            color: AppThemeColors.error,
            width: 1.4,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeColors.primary,
          foregroundColor: AppThemeColors.white,
          disabledBackgroundColor: AppThemeColors.surface2,
          disabledForegroundColor: AppThemeColors.textMuted,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppThemeColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppThemeColors.primary),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppThemeColors.primary,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppThemeColors.surface,
        selectedColor: AppThemeColors.primary,
        disabledColor: AppThemeColors.surface2,
        secondarySelectedColor: AppThemeColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: textTheme.labelSmall ?? const TextStyle(),
        secondaryLabelStyle: (textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: AppThemeColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          side: const BorderSide(color: AppThemeColors.border),
        ),
        side: const BorderSide(color: AppThemeColors.border),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppThemeColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppThemeColors.white,
        ),
        actionTextColor: AppThemeColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: brandPrimary,
        unselectedItemColor: navUnselected,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: brandPrimary,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: navUnselected,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppThemeColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppThemeColors.primary.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelSmall ?? const TextStyle();
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: AppThemeColors.primary);
          }
          return base.copyWith(color: AppThemeColors.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppThemeColors.primary, size: 24);
          }
          return const IconThemeData(color: AppThemeColors.textMuted, size: 24);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppThemeColors.primary,
        foregroundColor: AppThemeColors.white,
        elevation: 0,
        highlightElevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: AppThemeColors.primary,
      onPrimary: AppThemeColors.white,
      secondary: AppThemeColors.freshGreen,
      onSecondary: AppThemeColors.white,
      error: AppThemeColors.error,
      onError: AppThemeColors.white,
      surface: AppThemeColors.darkSurface,
      onSurface: AppThemeColors.darkTextPrimary,
    );

    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppThemeColors.darkBackground,
      canvasColor: AppThemeColors.darkBackground,
      dividerColor: AppThemeColors.darkDivider,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      textTheme: darkTextTheme,
      primaryTextTheme: darkTextTheme,
      iconTheme: const IconThemeData(color: AppThemeColors.darkTextPrimary),
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface,
        foregroundColor: AppThemeColors.darkTextPrimary,
        titleTextStyle: darkTextTheme.titleLarge,
        iconTheme: const IconThemeData(
          color: AppThemeColors.darkTextPrimary,
          size: 24,
        ),
      ),
      cardTheme: lightTheme.cardTheme.copyWith(
        color: AppThemeColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          side: const BorderSide(color: AppThemeColors.darkBorder),
        ),
      ),
      dialogTheme: lightTheme.dialogTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface,
        titleTextStyle: darkTextTheme.titleLarge,
        contentTextStyle: darkTextTheme.bodyMedium,
      ),
      bottomSheetTheme: lightTheme.bottomSheetTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface,
      ),
      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        fillColor: AppThemeColors.darkSurface2,
        hintStyle: darkTextTheme.bodyMedium?.copyWith(
          color: AppThemeColors.darkTextMuted,
        ),
        labelStyle: darkTextTheme.bodyMedium?.copyWith(
          color: AppThemeColors.darkTextSecondary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          borderSide: const BorderSide(color: AppThemeColors.darkBorder),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          borderSide: const BorderSide(color: AppThemeColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          borderSide: const BorderSide(
            color: AppThemeColors.primary,
            width: 1.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: lightTheme.outlinedButtonTheme.style?.copyWith(
          side: WidgetStateProperty.all(
            const BorderSide(color: AppThemeColors.primary),
          ),
          foregroundColor: WidgetStateProperty.all(AppThemeColors.primaryLight),
        ),
      ),
      chipTheme: lightTheme.chipTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface2,
        disabledColor: AppThemeColors.darkSurface2,
        side: const BorderSide(color: AppThemeColors.darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          side: const BorderSide(color: AppThemeColors.darkBorder),
        ),
        labelStyle: (darkTextTheme.labelSmall ?? const TextStyle()).copyWith(
          color: AppThemeColors.darkTextSecondary,
        ),
        secondaryLabelStyle:
            (darkTextTheme.labelSmall ?? const TextStyle()).copyWith(
          color: AppThemeColors.white,
        ),
      ),
      snackBarTheme: lightTheme.snackBarTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface2,
        contentTextStyle: darkTextTheme.bodyMedium?.copyWith(
          color: AppThemeColors.darkTextPrimary,
        ),
      ),
      bottomNavigationBarTheme: lightTheme.bottomNavigationBarTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface,
        selectedItemColor: AppThemeColors.primary,
        unselectedItemColor: AppThemeColors.darkTextMuted,
        selectedLabelStyle: darkTextTheme.labelSmall?.copyWith(
          color: AppThemeColors.primary,
        ),
        unselectedLabelStyle: darkTextTheme.labelSmall?.copyWith(
          color: AppThemeColors.darkTextMuted,
        ),
      ),
      navigationBarTheme: lightTheme.navigationBarTheme.copyWith(
        backgroundColor: AppThemeColors.darkSurface,
        indicatorColor: AppThemeColors.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = darkTextTheme.labelSmall ?? const TextStyle();
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: AppThemeColors.primary);
          }
          return base.copyWith(color: AppThemeColors.darkTextMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppThemeColors.primary, size: 24);
          }
          return const IconThemeData(
            color: AppThemeColors.darkTextMuted,
            size: 24,
          );
        }),
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
      double? letterSpacing,
    }) {
      return GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: poppins(
        size: 28,
        weight: FontWeight.w700,
        color: primaryColor,
        height: 1.2,
      ),
      displayMedium: poppins(
        size: 24,
        weight: FontWeight.w700,
        color: primaryColor,
        height: 1.2,
      ),
      displaySmall: poppins(
        size: 22,
        weight: FontWeight.w700,
        color: primaryColor,
        height: 1.2,
      ),
      headlineLarge: poppins(
        size: 24,
        weight: FontWeight.w700,
        color: primaryColor,
      ),
      headlineMedium: poppins(
        size: 22,
        weight: FontWeight.w700,
        color: primaryColor,
      ),
      headlineSmall: poppins(
        size: 20,
        weight: FontWeight.w700,
        color: primaryColor,
      ),
      titleLarge: poppins(
        size: 18,
        weight: FontWeight.w600,
        color: primaryColor,
      ),
      titleMedium: poppins(
        size: 16,
        weight: FontWeight.w600,
        color: primaryColor,
      ),
      titleSmall: poppins(
        size: 14,
        weight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: poppins(
        size: 15,
        weight: FontWeight.w400,
        color: primaryColor,
        height: 1.45,
      ),
      bodyMedium: poppins(
        size: 14,
        weight: FontWeight.w400,
        color: secondaryColor,
        height: 1.45,
      ),
      bodySmall: poppins(
        size: 12,
        weight: FontWeight.w400,
        color: mutedColor,
        height: 1.4,
      ),
      labelLarge: poppins(
        size: 14,
        weight: FontWeight.w600,
        color: primaryColor,
        height: 1.2,
      ),
      labelMedium: poppins(
        size: 12,
        weight: FontWeight.w600,
        color: secondaryColor,
        height: 1.2,
      ),
      labelSmall: poppins(
        size: 11,
        weight: FontWeight.w500,
        color: secondaryColor,
        height: 1.2,
        letterSpacing: 0.1,
      ),
    );
  }
}
