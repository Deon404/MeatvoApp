import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../ui/atoms/safe_icon_tap.dart';
import 'premium_cart_card.dart';

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
    final textTheme = Theme.of(context).textTheme;
    final couponCode = widget.appliedCode;
    final hasCoupon = couponCode != null && couponCode.isNotEmpty;

    if (!hasCoupon) {
      return GestureDetector(
        onTap: _showCouponDialog,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: Color(0xFFC8102E),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Apply Coupon',
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF6B6B6B),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF22C55E),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${couponCode.toUpperCase()} — ₹${widget.appliedDiscount.toStringAsFixed(0)} saved',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1A1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(
              Icons.close,
              color: Color(0xFF6B6B6B),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCouponDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
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
