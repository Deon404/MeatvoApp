import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

class CartCouponSection extends StatefulWidget {
  const CartCouponSection({
    super.key,
    required this.onApply,
    this.appliedCode,
    this.appliedDiscount = 0,
    this.errorMessage,
    this.onRemove,
  });

  final Future<bool> Function(String code) onApply;
  final String? appliedCode;
  final double appliedDiscount;
  final String? errorMessage;
  final VoidCallback? onRemove;

  @override
  State<CartCouponSection> createState() => _CartCouponSectionState();
}

class _CartCouponSectionState extends State<CartCouponSection> {
  final _controller = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() => _isApplying = true);
    HapticFeedback.lightImpact();

    final success = await widget.onApply(code);

    if (!mounted) return;
    setState(() => _isApplying = false);

    if (success) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final couponCode = widget.appliedCode;
    final hasCoupon = couponCode != null && couponCode.isNotEmpty;

    final cardDecoration = BoxDecoration(
      color: mv.surfaceCard,
      borderRadius: BorderRadius.circular(mv.radii.lg),
      boxShadow: mv.shadowCard,
    );

    if (!hasCoupon) {
      return GestureDetector(
        onTap: _showCouponDialog,
        child: Container(
          padding: EdgeInsets.all(mv.spacing.sm + 2),
          decoration: cardDecoration,
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: mv.brandPrimary, size: 20),
              SizedBox(width: mv.spacing.sm),
              Text(
                'Apply Coupon',
                style: textTheme.bodyMedium?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: mv.textMuted, size: 20),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(mv.spacing.sm + 2),
      decoration: cardDecoration,
      child: Row(
        children: [
          Icon(Icons.check_circle, color: mv.freshBadge, size: 20),
          SizedBox(width: mv.spacing.sm),
          Expanded(
            child: Text(
              '${couponCode.toUpperCase()} — ₹${widget.appliedDiscount.toStringAsFixed(0)} saved',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: mv.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: mv.spacing.xs),
          GestureDetector(
            onTap: widget.onRemove,
            child: Icon(Icons.close, color: mv.textMuted, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _showCouponDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Coupon Code'),
        content: TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Enter code',
            errorText: widget.errorMessage,
          ),
          onSubmitted: (_) => _applyAndPop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _applyAndPop,
            child: _isApplying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyAndPop() async {
    await _apply();
    if (!mounted) return;
    if (widget.appliedCode != null && widget.appliedCode!.isNotEmpty) {
      Navigator.pop(context);
    }
  }
}
