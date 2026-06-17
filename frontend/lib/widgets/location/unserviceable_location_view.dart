import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../onboarding/delivery_location_illustration.dart';

/// Zappfresh-style home empty state when delivery zone is unavailable.
class UnserviceableLocationView extends StatelessWidget {
  final VoidCallback onChangeLocation;

  const UnserviceableLocationView({
    super.key,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DeliveryLocationIllustration(
              height: 160,
              variant: DeliveryIllustrationVariant.permission,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Meatvo is not available in your selected location',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onChangeLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: const Text(
                  'Change location',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
