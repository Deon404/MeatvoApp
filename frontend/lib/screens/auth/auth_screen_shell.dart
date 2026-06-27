import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../utils/responsive_helper.dart';

/// Logo-only header for flat Zappfresh-style auth screens.
class AuthLogoHeader extends StatelessWidget {
  const AuthLogoHeader({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final width = compact ? 100.0 : 120.0;

    return Center(
      child: Image.asset(
        'assets/images/meatvo_logo.png',
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/icons/logo.png',
          width: compact ? 76 : 92,
          height: compact ? 76 : 92,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: compact ? 76 : 92,
            height: compact ? 76 : 92,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(mv.radii.xl),
            ),
            child: Icon(
              Icons.kebab_dining_outlined,
              color: mv.brandPrimary,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy brand header — kept for reference screens.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/logo.png',
            width: compact ? 76 : 92,
            height: compact ? 76 : 92,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: compact ? 76 : 92,
              height: compact ? 76 : 92,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(mv.radii.xl),
              ),
              child: Icon(
                Icons.kebab_dining_outlined,
                color: mv.brandPrimary,
                size: 40,
              ),
            ),
          ),
          SizedBox(height: mv.spacing.sm),
          Text(
            'Meatvo',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: mv.brandPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: mv.spacing.xxs),
          Text(
            'Premium cuts, delivered in 30 minutes',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mv.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// White card wrapper for legacy auth forms.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.child,
    this.compact = false,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return Container(
      padding: EdgeInsets.all(
        compact ? mv.spacing.lg : mv.spacing.xl,
      ),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.xl),
        border: Border.all(color: mv.border),
        boxShadow: mv.shadowMd,
      ),
      child: child,
    );
  }
}

/// Full-screen scaffold wrapper for flat Zappfresh-style auth screens.
class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.children,
    this.bottomFooter,
    this.flat = true,
  });

  final List<Widget> children;
  final Widget? bottomFooter;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final compact = keyboardOpen || media.size.height < 700;

    final horizontal = media.size.width > 480
        ? ((media.size.width - 420) / 2).clamp(24.0, 56.0).toDouble()
        : mv.spacing.xl;
    final topPadding = compact ? mv.spacing.md : mv.spacing.xl;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: flat ? MeatvoColors.white : mv.surfaceWarm,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                topPadding,
                horizontal,
                keyboardInset(context) + mv.spacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                        if (bottomFooter != null) ...[
                          SizedBox(height: compact ? mv.spacing.lg : mv.spacing.xxl),
                          bottomFooter!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
