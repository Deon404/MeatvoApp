import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Staff kitchen UI palette — black / white / red (scoped to staff screens only).
abstract final class StaffColors {
  static const background = Color(0xFF0F0F0F);
  static const surface = Color(0xFF1C1C1E);
  static const border = Color(0xFF2C2C2E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA0A0A0);
  static const accent = Color(0xFFC8102E);
  static const accentMuted = Color(0x33C8102E);
  static const chipNewBorder = Color(0xFFFFFFFF);
  static const chipPreparingBg = Color(0x26C8102E);
  static const divider = Color(0xFF2C2C2E);
  static const navBar = Color(0xFF0A0A0A);
}

abstract final class StaffTextStyles {
  static const h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: StaffColors.textPrimary,
    fontFamily: 'Poppins',
  );

  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: StaffColors.textPrimary,
    fontFamily: 'Poppins',
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: StaffColors.textPrimary,
    fontFamily: 'Poppins',
    height: 1.45,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: StaffColors.textSecondary,
    fontFamily: 'Poppins',
  );

  static const tabActive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: StaffColors.textPrimary,
    fontFamily: 'Poppins',
  );

  static const tabInactive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: StaffColors.textSecondary,
    fontFamily: 'Poppins',
  );

  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: StaffColors.textPrimary,
    fontFamily: 'Poppins',
  );
}

/// Dark app bar theme for staff kitchen screens.
PreferredSizeWidget staffAppBar({
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title, style: StaffTextStyles.h1.copyWith(fontSize: 20)),
    backgroundColor: StaffColors.surface,
    foregroundColor: StaffColors.textPrimary,
    elevation: 0,
    actions: actions,
  );
}

/// Reuse spacing/radii from global tokens where convenient.
abstract final class StaffSpacing {
  static const xs = AppSpacing.xs;
  static const sm = AppSpacing.sm;
  static const md = AppSpacing.md;
  static const lg = AppSpacing.lg;
}

abstract final class StaffRadius {
  static const card = AppRadius.card;
  static const button = AppRadius.button;
  static const chip = AppRadius.chip;
}
