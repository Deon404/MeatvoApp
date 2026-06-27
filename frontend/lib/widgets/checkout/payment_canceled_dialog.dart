import 'package:flutter/material.dart';

import '../../design_system/tokens/meatvo_colors.dart';

/// Compact dark dialog for payment cancellation (Zappfresh-style).
class PaymentCanceledDialog extends StatelessWidget {
  const PaymentCanceledDialog({
    super.key,
    this.message =
        'Your payment process was canceled. Please try again or choose a different payment method.',
  });

  final String message;

  static Future<void> show(
    BuildContext context, {
    String? message,
    VoidCallback? onOk,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentCanceledDialog(
        message: message ??
            'Your payment process was canceled. Please try again or choose a different payment method.',
      ),
    ).then((_) => onOk?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MeatvoColors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Payment canceled',
              style: TextStyle(
                color: MeatvoColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: MeatvoColors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: MeatvoColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
