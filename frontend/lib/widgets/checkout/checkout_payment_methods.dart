import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/payment_service.dart';

export 'checkout_payment_types.dart';

// ── UPI brand definitions ────────────────────────────────────────────────────

class _UpiBrand {
  const _UpiBrand({
    required this.color,
    required this.label,
    required this.icon,
  });
  final Color color;
  final String label;
  final IconData icon;
}

/// Returns a brand-styled avatar for a known UPI app package.
/// Falls back to a colored circle with the first letter of [displayName].
Widget upiAppAvatar(String packageId, String displayName, {double size = 32}) {
  final lower = packageId.toLowerCase();

  if (lower.contains('google') || lower.contains('tez') || lower.contains('paisa')) {
    return _BrandAvatar(size: size, label: 'G', color1: const Color(0xFF4285F4), color2: const Color(0xFF34A853));
  }
  if (lower.contains('phonepe') || lower.contains('phone_pe')) {
    return _BrandAvatar(size: size, label: 'Pe', color1: const Color(0xFF5F259F), color2: const Color(0xFF8347D3));
  }
  if (lower.contains('paytm')) {
    return _BrandAvatar(size: size, label: 'Pt', color1: const Color(0xFF00BAF2), color2: const Color(0xFF0086C3));
  }
  if (lower.contains('whatsapp')) {
    return _BrandAvatar(size: size, label: 'W', color1: const Color(0xFF25D366), color2: const Color(0xFF128C7E));
  }
  if (lower.contains('bhim') || lower.contains('npci')) {
    return _BrandAvatar(size: size, label: 'B', color1: const Color(0xFF00529B), color2: const Color(0xFF003D7A));
  }
  if (lower.contains('amazon')) {
    return _BrandAvatar(size: size, label: 'A', color1: const Color(0xFFFF9900), color2: const Color(0xFFCC7A00));
  }
  if (lower.contains('slice')) {
    return _BrandAvatar(size: size, label: 'Sl', color1: const Color(0xFF6C3CE1), color2: const Color(0xFF4A26A0));
  }
  if (lower.contains('mobikwik')) {
    return _BrandAvatar(size: size, label: 'Mk', color1: const Color(0xFF00BAF2), color2: const Color(0xFF0091C7));
  }
  if (lower.contains('freecharge')) {
    return _BrandAvatar(size: size, label: 'Fc', color1: const Color(0xFF4CAF50), color2: const Color(0xFF388E3C));
  }
  if (lower.contains('airtel')) {
    return _BrandAvatar(size: size, label: 'Ai', color1: const Color(0xFFE40000), color2: const Color(0xFFAB0000));
  }
  if (lower.contains('cred')) {
    return _BrandAvatar(size: size, label: 'C', color1: const Color(0xFF1A1A2E), color2: const Color(0xFF16213E));
  }

  // Generic fallback: first letter of displayName
  final initials = displayName.isNotEmpty
      ? displayName.substring(0, displayName.length > 1 ? 2 : 1).toUpperCase()
      : '?';
  final hue = (packageId.codeUnits.fold(0, (v, e) => v + e) % 360).toDouble();
  final color = HSLColor.fromAHSL(1, hue, 0.6, 0.45).toColor();
  return _BrandAvatar(size: size, label: initials, color1: color, color2: color.withValues(alpha: 0.7));
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({
    required this.size,
    required this.label,
    required this.color1,
    required this.color2,
  });

  final double size;
  final String label;
  final Color color1;
  final Color color2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ── CheckoutUpiChip ──────────────────────────────────────────────────────────

/// Reusable UPI app chip for payment options screen.
class CheckoutUpiChip extends StatelessWidget {
  const CheckoutUpiChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.packageId,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  /// When provided, shows a branded avatar instead of a generic icon.
  final String? packageId;

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
              if (packageId != null)
                upiAppAvatar(packageId!, label, size: 18)
              else
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? mv.brandPrimary : mv.textMuted,
                ),
              const SizedBox(width: 5),
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

// ── CheckoutUpiAppsLoader ────────────────────────────────────────────────────

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
