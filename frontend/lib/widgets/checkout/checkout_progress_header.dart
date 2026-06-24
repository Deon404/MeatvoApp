import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

/// Lightweight text + bar progress for checkout flow.
class CheckoutProgressHeader extends StatelessWidget {
  const CheckoutProgressHeader({
    super.key,
    this.activeStep = 2,
  });

  /// 1 = address, 2 = payment, 3 = review
  final int activeStep;

  static const _steps = ['Address', 'Payment', 'Review'];

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final clampedStep = activeStep.clamp(1, _steps.length);
    final stepLabel = _steps[clampedStep - 1];

    return Padding(
      padding: EdgeInsets.only(bottom: mv.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: clampedStep / _steps.length,
              minHeight: 3,
              backgroundColor: mv.border,
              color: mv.brandPrimary,
            ),
          ),
          SizedBox(height: mv.spacing.xs),
          Text(
            'Step $clampedStep of ${_steps.length} · $stepLabel',
            style: textTheme.labelMedium?.copyWith(
              color: mv.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
