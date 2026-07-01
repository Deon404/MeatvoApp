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

  Future<bool> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return false;

    setState(() => _isApplying = true);
    HapticFeedback.lightImpact();

    final success = await widget.onApply(code);

    if (!mounted) return false;
    setState(() => _isApplying = false);

    if (success) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    final cardDecoration = BoxDecoration(
      color: mv.surfaceCard,
      borderRadius: BorderRadius.circular(mv.radii.lg),
      border: Border.all(color: mv.border),
    );

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

  Future<void> _showCouponDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Enter Coupon Code'),
            content: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter code',
                errorText: widget.errorMessage,
              ),
              onSubmitted: (_) => _applyAndPop(dialogContext, setDialogState),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => _applyAndPop(dialogContext, setDialogState),
                child: _isApplying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyAndPop(
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
  ) async {
    final success = await _apply();
    if (!mounted) return;
    setDialogState(() {});
    if (success && dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
  }
}
