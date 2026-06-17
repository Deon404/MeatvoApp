import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/store_status_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/eta_display_util.dart';

/// Sticky inline banner shown when the store is not accepting orders.
class StoreClosedBanner extends StatelessWidget {
  const StoreClosedBanner({
    super.key,
    required this.status,
    this.padding,
  });

  final StoreStatus status;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (status.isOpen) return const SizedBox.shrink();

    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final message = status.displayClosedMessage;

    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(mv.spacing.md, 0, mv.spacing.md, mv.spacing.sm),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(mv.spacing.sm),
        decoration: BoxDecoration(
          color: etaOrangeBg,
          borderRadius: BorderRadius.circular(mv.radii.md),
          border: Border.all(color: etaOrange.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.store_mall_directory_outlined,
              color: etaOrange,
              size: 20,
            ),
            SizedBox(width: mv.spacing.sm),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: mv.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
