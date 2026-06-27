import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/payment_service.dart';
import 'checkout_section_header.dart';

enum CheckoutPaymentOption { online, cod }

extension CheckoutPaymentOptionX on CheckoutPaymentOption {
  String get backendValue =>
      this == CheckoutPaymentOption.cod ? 'COD' : 'ONLINE';

  String get label => switch (this) {
        CheckoutPaymentOption.online => 'Pay Online',
        CheckoutPaymentOption.cod => 'Cash on Delivery',
      };

  String get subtitle => switch (this) {
        CheckoutPaymentOption.online => 'UPI, cards & wallets via Cashfree',
        CheckoutPaymentOption.cod => 'Pay when your order arrives',
      };

  IconData get icon => switch (this) {
        CheckoutPaymentOption.online => Icons.account_balance_wallet_outlined,
        CheckoutPaymentOption.cod => Icons.payments_outlined,
      };
}

/// User's UPI quick-pay selection on checkout.
enum CheckoutUpiSelection {
  nativePicker,
  installedApp,
  webCheckout,
}

class CheckoutPaymentMethods extends StatefulWidget {
  const CheckoutPaymentMethods({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.upiSelection,
    required this.selectedUpiPackageId,
    required this.onUpiSelectionChanged,
    this.paymentService,
  });

  final CheckoutPaymentOption selected;
  final ValueChanged<CheckoutPaymentOption> onSelected;
  final CheckoutUpiSelection upiSelection;
  final String? selectedUpiPackageId;
  final void Function(CheckoutUpiSelection selection, String? packageId)
      onUpiSelectionChanged;
  final PaymentService? paymentService;

  @override
  State<CheckoutPaymentMethods> createState() => _CheckoutPaymentMethodsState();
}

class _CheckoutPaymentMethodsState extends State<CheckoutPaymentMethods> {
  List<InstalledUpiApp> _installedUpiApps = const [];
  bool _loadingUpiApps = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected == CheckoutPaymentOption.online) {
      _loadInstalledUpiApps();
    }
  }

  @override
  void didUpdateWidget(covariant CheckoutPaymentMethods oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == CheckoutPaymentOption.online &&
        oldWidget.selected != CheckoutPaymentOption.online &&
        _installedUpiApps.isEmpty &&
        !_loadingUpiApps) {
      _loadInstalledUpiApps();
    }
  }

  Future<void> _loadInstalledUpiApps() async {
    setState(() => _loadingUpiApps = true);
    final service = widget.paymentService ?? PaymentService();
    final apps = await service.getInstalledUpiApps();
    if (!mounted) return;
    setState(() {
      _installedUpiApps = apps;
      _loadingUpiApps = false;
    });
  }

  bool get _isUpiChipSelected {
    return widget.upiSelection == CheckoutUpiSelection.installedApp &&
        widget.selectedUpiPackageId != null;
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CheckoutSectionHeader(title: 'Pay with'),
        ...CheckoutPaymentOption.values.map((option) {
          final isSelected = widget.selected == option;
          final isRecommended = option == CheckoutPaymentOption.online;

          return _PaymentOptionRow(
            option: option,
            isSelected: isSelected,
            isRecommended: isRecommended,
            onTap: () => widget.onSelected(option),
          );
        }),
        if (widget.selected == CheckoutPaymentOption.online) ...[
          SizedBox(height: mv.spacing.sm),
          if (_loadingUpiApps)
            Text(
              'Checking installed UPI apps…',
              style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
            )
          else if (_installedUpiApps.isEmpty)
            Text(
              'No UPI apps detected — cards & wallets available at checkout.',
              style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final app in _installedUpiApps) ...[
                    _UpiChip(
                      label: app.displayName,
                      icon: Icons.phone_android_rounded,
                      isSelected: _isUpiChipSelected &&
                          widget.selectedUpiPackageId == app.packageId,
                      onTap: () => widget.onUpiSelectionChanged(
                        CheckoutUpiSelection.installedApp,
                        app.packageId,
                      ),
                    ),
                    SizedBox(width: mv.spacing.xs),
                  ],
                  _UpiChip(
                    label: 'All UPI apps',
                    icon: Icons.apps_rounded,
                    isSelected:
                        widget.upiSelection == CheckoutUpiSelection.nativePicker,
                    onTap: () => widget.onUpiSelectionChanged(
                      CheckoutUpiSelection.nativePicker,
                      null,
                    ),
                  ),
                  SizedBox(width: mv.spacing.xs),
                  _UpiChip(
                    label: 'More options',
                    icon: Icons.credit_card_rounded,
                    isSelected:
                        widget.upiSelection == CheckoutUpiSelection.webCheckout,
                    onTap: () => widget.onUpiSelectionChanged(
                      CheckoutUpiSelection.webCheckout,
                      null,
                    ),
                  ),
                ],
              ),
            ),
        ],
        SizedBox(height: mv.spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 13, color: mv.textMuted),
            const SizedBox(width: 4),
            Text(
              '256-bit secured · Powered by Cashfree',
              style: textTheme.bodySmall?.copyWith(
                color: mv.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentOptionRow extends StatelessWidget {
  const _PaymentOptionRow({
    required this.option,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  final CheckoutPaymentOption option;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: mv.spacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(mv.radii.md),
          child: Container(
            padding: EdgeInsets.all(mv.spacing.sm),
            decoration: BoxDecoration(
              color: isSelected
                  ? mv.brandPrimary.withValues(alpha: 0.04)
                  : mv.surfaceCard,
              borderRadius: BorderRadius.circular(mv.radii.md),
              border: Border.all(
                color: isSelected ? mv.brandPrimary : mv.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? mv.brandPrimary : mv.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mv.brandPrimary,
                            ),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: mv.spacing.sm),
                Icon(
                  option.icon,
                  size: 20,
                  color: isSelected ? mv.brandPrimary : mv.textSecondary,
                ),
                SizedBox(width: mv.spacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            option.label,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? mv.brandPrimary
                                  : mv.textPrimary,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 4),
                            Text(
                              '· Recommended',
                              style: textTheme.labelSmall?.copyWith(
                                color: mv.brandPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        option.subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: mv.textSecondary,
                        ),
                      ),
                    ],
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

class _UpiChip extends StatelessWidget {
  const _UpiChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(mv.radii.pill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: mv.spacing.sm,
            vertical: mv.spacing.xxs + 2,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? mv.brandPrimary.withValues(alpha: 0.12)
                : mv.surfaceWarm,
            borderRadius: BorderRadius.circular(mv.radii.pill),
            border: Border.all(
              color: isSelected ? mv.brandPrimary : mv.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? mv.brandPrimary : mv.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: isSelected ? mv.brandPrimary : mv.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
