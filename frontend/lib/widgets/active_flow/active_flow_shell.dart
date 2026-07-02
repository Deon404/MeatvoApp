import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class ActiveFlowBackground extends StatelessWidget {
  const ActiveFlowBackground({
    super.key,
    required this.child,
    this.baseColor = AppColors.warmBg,
    this.primaryGlow = const Color(0xFFFCE7EA),
    this.accentGlow = const Color(0xFFFFF2D8),
  });

  final Widget child;
  final Color baseColor;
  final Color primaryGlow;
  final Color accentGlow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: baseColor,
        gradient: LinearGradient(
          colors: [
            baseColor,
            primaryGlow.withValues(alpha: 0.35),
            baseColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            left: -32,
            child: _GlowOrb(
              size: 188,
              color: primaryGlow,
            ),
          ),
          Positioned(
            top: 92,
            right: -54,
            child: _GlowOrb(
              size: 160,
              color: accentGlow,
            ),
          ),
          Positioned(
            bottom: -72,
            right: -24,
            child: _GlowOrb(
              size: 176,
              color: primaryGlow.withValues(alpha: 0.75),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class ActiveFlowHeroCard extends StatelessWidget {
  const ActiveFlowHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.metrics = const <Widget>[],
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final List<Widget> metrics;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD11D35),
            Color(0xFF9E152A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33C8102E),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null || trailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Expanded(
                    child: Text(
                      eyebrow!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          if (eyebrow != null || trailing != null) const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metrics,
            ),
          ],
        ],
      ),
    );
  }
}

class ActiveFlowSurfaceCard extends StatelessWidget {
  const ActiveFlowSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = Colors.white,
    this.borderRadius = 22,
    this.borderColor = const Color(0xFFF2E7E5),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double borderRadius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ActiveFlowMetricPill extends StatelessWidget {
  const ActiveFlowMetricPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.inverted = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final background = inverted
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFF9F4F3);
    final valueColor = inverted ? Colors.white : AppColors.textDark;
    final labelColor = inverted ? Colors.white70 : AppColors.textMedium;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inverted
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFF0DFDB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: valueColor),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.9),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
