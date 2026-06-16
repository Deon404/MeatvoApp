import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class MeatvoButton extends StatelessWidget {
  const MeatvoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: Material(
          color: isOutlined ? Colors.transparent : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
            splashColor: isOutlined
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.primaryHover.withValues(alpha: 0.3),
            highlightColor: isOutlined
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.primaryHover.withValues(alpha: 0.2),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: isOutlined
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
                color: isOutlined ? Colors.transparent : AppColors.primary,
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOutlined ? AppColors.primary : AppColors.white,
                          ),
                        ),
                      )
                    : Text(
                        label,
                        style: AppTextStyles.button.copyWith(
                          color: isOutlined ? AppColors.primary : AppColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
