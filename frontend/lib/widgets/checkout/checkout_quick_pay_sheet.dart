import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../screens/checkout/checkout_payment_options_screen.dart';
import '../../services/payment_service.dart';
import 'checkout_payment_methods.dart';
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
    this.paymentService,
  });

  final double total;
  final CheckoutUpiSelection initialUpiSelection;
  final String? initialUpiPackageId;
  final PaymentService? paymentService;

  static Future<CheckoutQuickPayResult?> show(
    BuildContext context, {
    required double total,
    CheckoutUpiSelection upiSelection = CheckoutUpiSelection.nativePicker,
    String? upiPackageId,
    PaymentService? paymentService,
  }) {
    return showModalBottomSheet<CheckoutQuickPayResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutQuickPaySheet(
        total: total,
        initialUpiSelection: upiSelection,
        initialUpiPackageId: upiPackageId,
        paymentService: paymentService,
      ),
    );
  }

  @override
  State<CheckoutQuickPaySheet> createState() => _CheckoutQuickPaySheetState();
}

class _CheckoutQuickPaySheetState extends State<CheckoutQuickPaySheet> {
  late CheckoutUpiSelection _upiSelection;
  String? _upiPackageId;
  String _methodLabel = 'Pay Online';
  List<InstalledUpiApp> _installedApps = const [];

  @override
  void initState() {
    super.initState();
    _upiSelection = widget.initialUpiSelection;
    _upiPackageId = widget.initialUpiPackageId;
    _loadUpiApps();
  }

  Future<void> _loadUpiApps() async {
    final service = widget.paymentService ?? PaymentService();
    final apps = await service.getInstalledUpiApps();
    if (!mounted) return;
    setState(() {
      _installedApps = apps;
      _methodLabel = _resolveMethodLabel(apps);
    });
  }

  String _resolveMethodLabel(List<InstalledUpiApp> apps) {
    if (_upiSelection == CheckoutUpiSelection.installedApp &&
        _upiPackageId != null) {
      final match = apps.where((a) => a.packageId == _upiPackageId);
      if (match.isNotEmpty) return match.first.displayName;
    }
    if (_upiSelection == CheckoutUpiSelection.nativePicker) {
      return 'All UPI apps';
    }
    return 'Pay Online';
  }

  Future<void> _openMoreOptions() async {
    final result = await Navigator.of(context).push<CheckoutPaymentOptionsResult>(
      MaterialPageRoute(
        builder: (_) => CheckoutPaymentOptionsScreen(
          total: widget.total,
          initialOption: CheckoutPaymentOption.online,
          initialUpiSelection: _upiSelection,
          initialUpiPackageId: _upiPackageId,
          paymentService: widget.paymentService,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _upiSelection = result.upiSelection;
      _upiPackageId = result.upiPackageId;
      _methodLabel = _resolveMethodLabel(_installedApps);
    });
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
              children: [
                _upiPackageId != null
                    ? upiAppAvatar(_upiPackageId!, _methodLabel, size: 28)
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: mv.brandPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          size: 16,
                          color: mv.brandPrimary,
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _methodLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openMoreOptions,
                  child: Text(
                    'More Options',
                    style: textTheme.labelLarge?.copyWith(
                      color: mv.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
                'Pay',
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
