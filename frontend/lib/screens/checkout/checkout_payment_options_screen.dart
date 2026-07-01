import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/payment_service.dart';
import '../../widgets/checkout/checkout_payment_methods.dart';

class CheckoutPaymentOptionsResult {
  const CheckoutPaymentOptionsResult({
    required this.option,
    required this.upiSelection,
    this.upiPackageId,
  });

  final CheckoutPaymentOption option;
  final CheckoutUpiSelection upiSelection;
  final String? upiPackageId;
}

/// Simplified payment options — UPI chips + COD (Cashfree handles cards/netbanking).
class CheckoutPaymentOptionsScreen extends StatefulWidget {
  const CheckoutPaymentOptionsScreen({
    super.key,
    required this.total,
    required this.initialOption,
    this.initialUpiSelection = CheckoutUpiSelection.nativePicker,
    this.initialUpiPackageId,
    this.paymentService,
  });

  final double total;
  final CheckoutPaymentOption initialOption;
  final CheckoutUpiSelection initialUpiSelection;
  final String? initialUpiPackageId;
  final PaymentService? paymentService;

  @override
  State<CheckoutPaymentOptionsScreen> createState() =>
      _CheckoutPaymentOptionsScreenState();
}

class _CheckoutPaymentOptionsScreenState
    extends State<CheckoutPaymentOptionsScreen> {
  late CheckoutPaymentOption _option;
  late CheckoutUpiSelection _upiSelection;
  String? _upiPackageId;
  bool _onlineExpanded = true;

  @override
  void initState() {
    super.initState();
    _option = widget.initialOption;
    _upiSelection = widget.initialUpiSelection;
    _upiPackageId = widget.initialUpiPackageId;
  }

  void _continue() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      CheckoutPaymentOptionsResult(
        option: _option,
        upiSelection: _upiSelection,
        upiPackageId: _upiPackageId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final totalStr = widget.total
        .toStringAsFixed(widget.total.truncateToDouble() == widget.total ? 0 : 1);

    return Scaffold(
      backgroundColor: mv.surfaceWarm,
      appBar: AppBar(
        backgroundColor: mv.surfaceWarm,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: mv.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Options',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: mv.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(mv.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All payment options',
                    style: textTheme.labelMedium?.copyWith(
                      color: mv.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: mv.spacing.sm),
                  _OptionSection(
                    title: 'Pay Online',
                    icon: Icons.account_balance_wallet_outlined,
                    isExpanded: _onlineExpanded,
                    isSelected: _option == CheckoutPaymentOption.online,
                    onHeaderTap: () {
                      setState(() {
                        _option = CheckoutPaymentOption.online;
                        _onlineExpanded = !_onlineExpanded;
                      });
                    },
                    child: CheckoutUpiAppsLoader(
                      paymentService: widget.paymentService,
                      builder: (context, apps, loading) {
                        if (loading) {
                          return Padding(
                            padding: EdgeInsets.only(top: mv.spacing.sm),
                            child: Text(
                              'Checking installed UPI apps…',
                              style: textTheme.bodySmall?.copyWith(
                                color: mv.textMuted,
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: mv.spacing.sm),
                            Wrap(
                              spacing: mv.spacing.xs,
                              runSpacing: mv.spacing.xs,
                              children: [
                                for (final app in apps)
                                  CheckoutUpiChip(
                                    label: app.displayName,
                                    icon: Icons.phone_android_rounded,
                                    packageId: app.packageId,
                                    isSelected: _upiSelection ==
                                            CheckoutUpiSelection.installedApp &&
                                        _upiPackageId == app.packageId,
                                    onTap: () => setState(() {
                                      _option = CheckoutPaymentOption.online;
                                      _upiSelection =
                                          CheckoutUpiSelection.installedApp;
                                      _upiPackageId = app.packageId;
                                    }),
                                  ),
                                CheckoutUpiChip(
                                  label: 'All UPI apps',
                                  icon: Icons.apps_rounded,
                                  isSelected: _upiSelection ==
                                      CheckoutUpiSelection.nativePicker,
                                  onTap: () => setState(() {
                                    _option = CheckoutPaymentOption.online;
                                    _upiSelection =
                                        CheckoutUpiSelection.nativePicker;
                                    _upiPackageId = null;
                                  }),
                                ),
                              ],
                            ),
                            SizedBox(height: mv.spacing.sm),
                            Text(
                              'Cards & netbanking available in Cashfree checkout.',
                              style: textTheme.bodySmall?.copyWith(
                                color: mv.textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: mv.spacing.sm),
                  _OptionSection(
                    title: 'Cash on Delivery',
                    icon: Icons.payments_outlined,
                    isExpanded: false,
                    isSelected: _option == CheckoutPaymentOption.cod,
                    onHeaderTap: () => setState(() {
                      _option = CheckoutPaymentOption.cod;
                      _onlineExpanded = false;
                    }),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: mv.surfaceCard,
              border: Border(top: BorderSide(color: mv.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              mv.spacing.md,
              mv.spacing.sm,
              mv.spacing.md,
              mv.spacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹$totalStr',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'View details',
                      style: textTheme.labelSmall?.copyWith(
                        color: mv.textMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 140,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MeatvoColors.brandPrimaryDark,
                      foregroundColor: MeatvoColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(mv.radii.md),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: MeatvoColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.isSelected,
    required this.onHeaderTap,
    required this.child,
  });

  final String title;
  final IconData icon;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onHeaderTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? mv.brandPrimary : mv.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: mv.brandPrimary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: mv.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}
