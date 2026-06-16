import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_durations.dart';
import 'meatvo_layout.dart';

class MeatvoFloatingNavBar extends StatelessWidget {
  const MeatvoFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<MeatvoNavItem> items;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1);
    final showLabels = media.size.width >= 360 &&
        media.size.height >= 640 &&
        textScale <= 1.15;
    final compact = MeatvoLayout.isCompactHeight(context);

    return Positioned(
      left: MeatvoLayout.navBarMargin,
      right: MeatvoLayout.navBarMargin,
      bottom: MeatvoLayout.navBarBottomGap,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(mv.radii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: mv.surfaceCard.withValues(alpha: 0.96),
            elevation: 0,
            child: Container(
              height: MeatvoLayout.navBarHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(mv.radii.pill),
                border: Border.all(color: mv.border.withValues(alpha: 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: mv.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final selected = index == currentIndex;
                  return Expanded(
                    child: _NavTile(
                      item: item,
                      selected: selected,
                      showLabel: showLabels,
                      compact: compact,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(index);
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class MeatvoNavItem {
  const MeatvoNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget? badge;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.compact,
    required this.onTap,
  });

  final MeatvoNavItem item;
  final bool selected;
  final bool showLabel;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    // Smart-cast local — `item.badge!` bang removed. The badge can be
    // swapped to null on cart-empty events; without the local, that
    // mid-frame change would crash with "Null check operator used on
    // a null value".
    final badge = item.badge;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(mv.radii.lg),
      child: AnimatedContainer(
        duration: MeatvoDurations.normal,
        curve: MeatvoDurations.curve,
        margin: EdgeInsets.symmetric(
          horizontal: mv.spacing.xxs,
          vertical: compact ? mv.spacing.xxs : mv.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? mv.brandPrimary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(mv.radii.lg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: MeatvoDurations.fast,
                  curve: MeatvoDurations.curve,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    color: selected ? mv.brandPrimary : mv.textMuted,
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(right: -8, top: -4, child: badge),
              ],
            ),
            if (showLabel) ...[
              SizedBox(height: mv.spacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: MeatvoDurations.fast,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? mv.brandPrimary : mv.textMuted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ) ??
                      const TextStyle(),
                  child: Text(item.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
