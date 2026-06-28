import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color = AppColors.primary,
    this.dataAvailable = true,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final bool dataAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: dataAvailable ? AppColors.divider : AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption,
                ),
              ),
              if (!dataAvailable)
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.warning.withValues(alpha: 0.9),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: dataAvailable ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
