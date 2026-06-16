import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_durations.dart';

class MeatvoChip extends StatelessWidget {
  const MeatvoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return AnimatedContainer(
      duration: MeatvoDurations.fast,
      curve: MeatvoDurations.curve,
      decoration: BoxDecoration(
        color: selected ? mv.brandPrimary : mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.pill),
        border: Border.all(
          color: selected ? mv.brandPrimary : mv.border,
        ),
        boxShadow: selected ? mv.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(mv.radii.pill),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: mv.spacing.md,
              vertical: mv.spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Local + smart-cast removes the `leading!` bang. With null
                // safety, `leading` could be a getter that returns null on
                // a subsequent rebuild; a local makes the access provably
                // non-null.
                if (leading case final Widget l) ...[
                  l,
                  SizedBox(width: mv.spacing.xs),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? Colors.white : mv.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
