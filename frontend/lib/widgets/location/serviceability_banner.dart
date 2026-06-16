import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';

class ServiceabilityBanner extends StatelessWidget {
  final bool isServiceable;
  final String? distanceLabel;

  const ServiceabilityBanner({
    super.key,
    required this.isServiceable,
    this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isServiceable
        ? AppColors.success.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.12);
    final fg = isServiceable ? AppColors.success : Colors.red;
    final icon = isServiceable ? Icons.check_circle_rounded : Icons.block_rounded;
    final message = isServiceable
        ? 'Delivery available${distanceLabel != null ? ' · $distanceLabel' : ''}'
        : 'Outside delivery zone${distanceLabel != null ? ' · $distanceLabel' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MeatvoSpacing.md,
        vertical: MeatvoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MeatvoRadii.md),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: MeatvoSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
