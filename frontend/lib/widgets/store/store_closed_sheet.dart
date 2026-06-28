import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../services/store_status_service.dart';

/// Bottom sheet shown when the store is closed (manual toggle or outside hours).
class StoreClosedSheet extends StatelessWidget {
  const StoreClosedSheet({
    super.key,
    required this.status,
  });

  final StoreStatus status;

  static Future<void> show(BuildContext context, StoreStatus status) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => StoreClosedSheet(status: status),
    );
  }

  String get _hoursLabel => status.displayStoreHours ?? '';

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: EdgeInsets.all(mv.spacing.md),
        decoration: BoxDecoration(
          color: mv.surfaceCard,
          borderRadius: BorderRadius.circular(mv.radii.lg),
          boxShadow: [
            BoxShadow(
              color: MeatvoColors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mv.spacing.lg,
              mv.spacing.lg,
              mv.spacing.lg,
              mv.spacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mv.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                SizedBox(height: mv.spacing.lg),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_mall_directory_outlined,
                    color: mv.brandPrimary,
                    size: 34,
                  ),
                ),
                SizedBox(height: mv.spacing.lg),
                Text(
                  status.isAcceptingOrders
                      ? 'Limited Capacity'
                      : 'Not Accepting Orders',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mv.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mv.spacing.sm),
                Text(
                  status.isAcceptingOrders
                      ? (status.displayCapacityMessage ?? '')
                      : status.displayClosedMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: mv.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_hoursLabel.isNotEmpty) ...[
                  SizedBox(height: mv.spacing.md),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(mv.spacing.md),
                    decoration: BoxDecoration(
                      color: mv.surfaceWarm,
                      borderRadius: BorderRadius.circular(mv.radii.md),
                      border: Border.all(color: mv.border.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: mv.textSecondary,
                          size: 20,
                        ),
                        SizedBox(width: mv.spacing.sm),
                        Expanded(
                          child: Text(
                            'Store hours: $_hoursLabel',
                            style: textTheme.bodySmall?.copyWith(
                              color: mv.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: mv.spacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: mv.brandPrimary,
                      foregroundColor: MeatvoColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(mv.radii.pill),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: textTheme.titleSmall?.copyWith(
                        color: MeatvoColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
