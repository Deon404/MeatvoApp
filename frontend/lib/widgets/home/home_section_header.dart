import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_layout.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Smart-cast locals — `actionLabel!` / `onAction!()` removed.
    final label = actionLabel;
    final action = onAction;
    final showAction = label != null && label.isNotEmpty && action != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeLayout.horizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HomeLayout.sectionTitleStyle,
            ),
          ),
          if (showAction)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                action.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFCC0000),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
