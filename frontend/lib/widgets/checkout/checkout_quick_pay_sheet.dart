import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import 'checkout_payment_types.dart';

/// Result from quick-pay sheet when user confirms payment.
class CheckoutQuickPayResult {
  const CheckoutQuickPayResult({
    required this.confirmed,
    this.upiSelection = CheckoutUpiSelection.nativePicker,
    this.upiPackageId,
  });

  final bool confirmed;
  final CheckoutUpiSelection upiSelection;
  final String? upiPackageId;
}

/// Bottom sheet — Pay ₹X with selected UPI / online method.
class CheckoutQuickPaySheet extends StatefulWidget {
  const CheckoutQuickPaySheet({
    super.key,
    required this.total,
    required this.initialUpiSelection,
    this.initialUpiPackageId,
  });

  final double total;
  final CheckoutUpiSelection initialUpiSelection;
  final String? initialUpiPackageId;

  static Future<CheckoutQuickPayResult?> show(
    BuildContext context, {
    required double total,
    CheckoutUpiSelection upiSelection = CheckoutUpiSelection.nativePicker,
    String? upiPackageId,
  }) {
    return showModalBottomSheet<CheckoutQuickPayResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutQuickPaySheet(
        total: total,
        initialUpiSelection: upiSelection,
        initialUpiPackageId: upiPackageId,
      ),
    );
  }

  @override
  State<CheckoutQuickPaySheet> createState() => _CheckoutQuickPaySheetState();
}

class _CheckoutQuickPaySheetState extends State<CheckoutQuickPaySheet> {
  late CheckoutUpiSelection _upiSelection;
  String? _upiPackageId;
  late String _methodLabel;

  @override
  void initState() {
    super.initState();
    // Let Cashfree own UPI app detection and logos instead of maintaining
    // a custom app picker in-app.
    _upiSelection = CheckoutUpiSelection.nativePicker;
    _upiPackageId = null;
    _methodLabel = 'UPI apps in Cashfree';
  }

  void _confirmPay() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      CheckoutQuickPayResult(
        confirmed: true,
        upiSelection: _upiSelection,
        upiPackageId: _upiPackageId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final totalStr =
        widget.total.toStringAsFixed(widget.total.truncateToDouble() == widget.total ? 0 : 1);

    return Container(
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        mv.spacing.lg,
        mv.spacing.md,
        mv.spacing.lg,
        mv.spacing.lg + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pay ₹$totalStr',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: mv.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: mv.textPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          SizedBox(height: mv.spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: MeatvoColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: mv.brandPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: mv.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _methodLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cashfree will detect installed UPI apps automatically.',
                        style: textTheme.bodySmall?.copyWith(
                          color: mv.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: mv.spacing.sm),
          Text(
            'Cards, netbanking and more payment methods stay available inside Cashfree checkout.',
            style: textTheme.bodySmall?.copyWith(
              color: mv.textMuted,
              height: 1.4,
            ),
          ),
          SizedBox(height: mv.spacing.lg),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _confirmPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: MeatvoColors.brandPrimaryDark,
                foregroundColor: MeatvoColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mv.radii.pill),
                ),
              ),
              child: Text(
                'Continue to Cashfree',
                style: textTheme.titleSmall?.copyWith(
                  color: MeatvoColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: mv.spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 13, color: mv.textMuted),
              const SizedBox(width: 4),
              Text(
                'Secured by Cashfree',
                style: textTheme.bodySmall?.copyWith(
                  color: mv.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
