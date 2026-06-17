import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Zappfresh-style freshness reassurance strip on tracking screen.
class OrderFreshnessTrustStrip extends StatelessWidget {
  const OrderFreshnessTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.ac_unit_rounded, size: 18, color: AppColors.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Packed fresh · 0–4°C cold chain · Hygienically cut',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
