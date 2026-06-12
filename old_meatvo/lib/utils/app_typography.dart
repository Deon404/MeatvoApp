// DEPRECATED: Use AppTheme.textTheme instead
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Temporary compatibility wrapper while older screens migrate to `AppTheme`.
class AppTypography {
  static TextTheme _theme(BuildContext context) => Theme.of(context).textTheme;

  static TextStyle displayLarge(BuildContext context) =>
      _theme(context).displayLarge ?? AppTheme.textTheme.displayLarge!;

  static TextStyle displayMedium(BuildContext context) =>
      _theme(context).displayMedium ?? AppTheme.textTheme.displayMedium!;

  static TextStyle displaySmall(BuildContext context) =>
      _theme(context).displaySmall ?? AppTheme.textTheme.displaySmall!;

  static TextStyle headlineLarge(BuildContext context) =>
      _theme(context).headlineLarge ?? AppTheme.textTheme.headlineLarge!;

  static TextStyle headlineMedium(BuildContext context) =>
      _theme(context).headlineMedium ?? AppTheme.textTheme.headlineMedium!;

  static TextStyle headlineSmall(BuildContext context) =>
      _theme(context).headlineSmall ?? AppTheme.textTheme.headlineSmall!;

  static TextStyle titleLarge(BuildContext context) =>
      _theme(context).titleLarge ?? AppTheme.textTheme.titleLarge!;

  static TextStyle titleMedium(BuildContext context) =>
      _theme(context).titleMedium ?? AppTheme.textTheme.titleMedium!;

  static TextStyle titleSmall(BuildContext context) =>
      _theme(context).titleSmall ?? AppTheme.textTheme.titleSmall!;

  static TextStyle bodyLarge(BuildContext context) =>
      _theme(context).bodyLarge ?? AppTheme.textTheme.bodyLarge!;

  static TextStyle bodyMedium(BuildContext context) =>
      _theme(context).bodyMedium ?? AppTheme.textTheme.bodyMedium!;

  static TextStyle bodySmall(BuildContext context) =>
      _theme(context).bodySmall ?? AppTheme.textTheme.bodySmall!;

  static TextStyle labelLarge(BuildContext context) =>
      _theme(context).labelLarge ?? AppTheme.textTheme.labelLarge!;

  static TextStyle labelMedium(BuildContext context) =>
      _theme(context).labelMedium ?? AppTheme.textTheme.labelMedium!;

  static TextStyle labelSmall(BuildContext context) =>
      _theme(context).labelSmall ?? AppTheme.textTheme.labelSmall!;

  static TextStyle button(BuildContext context) =>
      labelLarge(context).copyWith(color: AppThemeColors.white);

  static TextStyle caption(BuildContext context) => bodySmall(context);

  static TextStyle overline(BuildContext context) => labelSmall(context);
}

