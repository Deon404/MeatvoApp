import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/payment_service.dart';

export 'checkout_payment_types.dart';

/// Reusable UPI app chip for payment options screen.
class CheckoutUpiChip extends StatelessWidget {
  const CheckoutUpiChip({
    super.key,
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

/// Loads installed UPI apps for payment options UI.
class CheckoutUpiAppsLoader extends StatefulWidget {
  const CheckoutUpiAppsLoader({
    super.key,
    required this.builder,
    this.paymentService,
  });

  final Widget Function(
    BuildContext context,
    List<InstalledUpiApp> apps,
    bool loading,
  ) builder;
  final PaymentService? paymentService;

  @override
  State<CheckoutUpiAppsLoader> createState() => _CheckoutUpiAppsLoaderState();
}

class _CheckoutUpiAppsLoaderState extends State<CheckoutUpiAppsLoader> {
  List<InstalledUpiApp> _apps = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = widget.paymentService ?? PaymentService();
    final apps = await service.getInstalledUpiApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _apps, _loading);
}
