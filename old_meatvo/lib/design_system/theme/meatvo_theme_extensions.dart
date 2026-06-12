import 'package:flutter/material.dart';

import '../tokens/meatvo_colors.dart';
import '../tokens/meatvo_radii.dart';
import '../tokens/meatvo_shadows.dart';
import '../tokens/meatvo_spacing.dart';

class MeatvoThemeData extends ThemeExtension<MeatvoThemeData> {
  const MeatvoThemeData({
    required this.brandPrimary,
    required this.brandPrimaryDark,
    required this.brandAccent,
    required this.surfaceWarm,
    required this.surfaceCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.error,
    required this.freshBadge,
    required this.spacing,
    required this.radii,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.shadowCard,
  });

  final Color brandPrimary;
  final Color brandPrimaryDark;
  final Color brandAccent;
  final Color surfaceWarm;
  final Color surfaceCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color error;
  final Color freshBadge;
  final MeatvoSpacingTokens spacing;
  final MeatvoRadiiTokens radii;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;
  final List<BoxShadow> shadowCard;

  static const MeatvoThemeData light = MeatvoThemeData(
    brandPrimary: MeatvoColors.brandPrimary,
    brandPrimaryDark: MeatvoColors.brandPrimaryDark,
    brandAccent: MeatvoColors.brandAccent,
    surfaceWarm: MeatvoColors.surfaceWarm,
    surfaceCard: MeatvoColors.surfaceCard,
    textPrimary: MeatvoColors.textPrimary,
    textSecondary: MeatvoColors.textSecondary,
    textMuted: MeatvoColors.textMuted,
    border: MeatvoColors.border,
    error: MeatvoColors.error,
    freshBadge: MeatvoColors.freshBadge,
    spacing: MeatvoSpacingTokens(),
    radii: MeatvoRadiiTokens(),
    shadowSm: MeatvoShadows.sm,
    shadowMd: MeatvoShadows.md,
    shadowLg: MeatvoShadows.lg,
    shadowCard: MeatvoShadows.card,
  );

  @override
  MeatvoThemeData copyWith({
    Color? brandPrimary,
    Color? brandPrimaryDark,
    Color? brandAccent,
    Color? surfaceWarm,
    Color? surfaceCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? error,
    Color? freshBadge,
    MeatvoSpacingTokens? spacing,
    MeatvoRadiiTokens? radii,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    List<BoxShadow>? shadowCard,
  }) {
    return MeatvoThemeData(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrimaryDark: brandPrimaryDark ?? this.brandPrimaryDark,
      brandAccent: brandAccent ?? this.brandAccent,
      surfaceWarm: surfaceWarm ?? this.surfaceWarm,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      error: error ?? this.error,
      freshBadge: freshBadge ?? this.freshBadge,
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      shadowCard: shadowCard ?? this.shadowCard,
    );
  }

  @override
  MeatvoThemeData lerp(ThemeExtension<MeatvoThemeData>? other, double t) {
    if (other is! MeatvoThemeData) return this;
    return MeatvoThemeData(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandPrimaryDark:
          Color.lerp(brandPrimaryDark, other.brandPrimaryDark, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      freshBadge: Color.lerp(freshBadge, other.freshBadge, t)!,
      spacing: spacing,
      radii: radii,
      shadowSm: shadowSm,
      shadowMd: shadowMd,
      shadowLg: shadowLg,
      shadowCard: shadowCard,
    );
  }
}

class MeatvoSpacingTokens {
  const MeatvoSpacingTokens();

  double get xxs => MeatvoSpacing.xxs;
  double get xs => MeatvoSpacing.xs;
  double get sm => MeatvoSpacing.sm;
  double get md => MeatvoSpacing.md;
  double get lg => MeatvoSpacing.lg;
  double get xl => MeatvoSpacing.xl;
  double get xxl => MeatvoSpacing.xxl;
}

class MeatvoRadiiTokens {
  const MeatvoRadiiTokens();

  double get sm => MeatvoRadii.sm;
  double get md => MeatvoRadii.md;
  double get lg => MeatvoRadii.lg;
  double get card => MeatvoRadii.card;
  double get xl => MeatvoRadii.xl;
  double get pill => MeatvoRadii.pill;
  double get navBar => MeatvoRadii.navBar;
}

extension MeatvoThemeContext on BuildContext {
  MeatvoThemeData get meatvo =>
      Theme.of(this).extension<MeatvoThemeData>() ?? MeatvoThemeData.light;
}
