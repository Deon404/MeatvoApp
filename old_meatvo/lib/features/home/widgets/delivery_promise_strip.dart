import 'package:flutter/material.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';

/// Thin trust ticker — sits at the top of the home banner block.
class DeliveryPromiseStrip extends StatelessWidget {
  const DeliveryPromiseStrip({super.key});

  static const double _height = 32;
  static const Color _background = Color(0xFFF8F8F8);

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    final badges = [
      (
        Icons.bolt_rounded,
        '30-min delivery',
        '30-min',
        mv.brandPrimary,
      ),
      (
        Icons.verified_outlined,
        'Quality assured',
        'Quality',
        MeatvoColors.freshBadge,
      ),
      (
        Icons.ac_unit_rounded,
        'Cold-chain packed',
        'Cold-chain',
        mv.textSecondary,
      ),
    ];

    return Container(
      height: _height,
      color: _background,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 320;
          final useShortLabel = constraints.maxWidth < 380;

          if (narrow) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: badges.length,
              separatorBuilder: (_, __) => _Divider(color: mv.border),
              itemBuilder: (context, index) {
                final badge = badges[index];
                return Center(
                  child: _TrustBadge(
                    icon: badge.$1,
                    label: badge.$3,
                    color: badge.$4,
                  ),
                );
              },
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < badges.length; i++) ...[
                if (i > 0) _Divider(color: mv.border),
                Flexible(
                  child: _TrustBadge(
                    icon: badges[i].$1,
                    label: useShortLabel ? badges[i].$3 : badges[i].$2,
                    color: badges[i].$4,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: color,
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MeatvoColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.1,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
