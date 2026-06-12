import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    // Smart-cast locals replace the `actionLabel!` bang.
    final label = actionLabel;
    final action = onAction;
    final showAction = label != null && label.isNotEmpty && action != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: mv.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (showAction)
            TextButton(
              onPressed: action,
              style: TextButton.styleFrom(
                foregroundColor: mv.brandPrimary,
                padding: EdgeInsets.symmetric(horizontal: mv.spacing.sm),
              ),
              child: Text(label),
            ),
        ],
      ),
    );
  }
}
