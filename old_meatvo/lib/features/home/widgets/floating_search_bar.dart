import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';

class FloatingSearchBar extends StatelessWidget {
  const FloatingSearchBar({
    super.key,
    required this.onTap,
    this.placeholder = HomeStrings.searchHint,
  });

  final VoidCallback onTap;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mv.spacing.md,
        mv.spacing.sm,
        mv.spacing.md,
        mv.spacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(mv.radii.pill),
          child: Ink(
            decoration: BoxDecoration(
              color: mv.surfaceCard,
              borderRadius: BorderRadius.circular(mv.radii.pill),
              border: Border.all(color: mv.border),
              boxShadow: mv.shadowSm,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mv.spacing.md,
                vertical: mv.spacing.sm + 2,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: mv.textMuted, size: 22),
                  SizedBox(width: mv.spacing.sm),
                  Expanded(
                    child: Text(
                      placeholder,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: mv.textMuted,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.mic_none_rounded,
                    color: mv.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
