import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../models/cart_model.dart';
import '../cached_image_widget.dart';

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    this.isBusy = false,
  });

  final CartItem item;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final qty = item.quantity.round();

    return Container(
      margin: EdgeInsets.symmetric(vertical: mv.spacing.xxs + 2),
      padding: EdgeInsets.all(mv.spacing.sm),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.lg),
        boxShadow: mv.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedImageWidget(
              imageUrl: item.product.primaryImageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: mv.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: mv.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: mv.spacing.xxs),
                Text(
                  item.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: mv.textSecondary),
                ),
                SizedBox(height: mv.spacing.xs),
                Text(
                  '₹${(item.unitPrice * qty).toStringAsFixed(0)}',
                  maxLines: 1,
                  style: textTheme.bodyMedium?.copyWith(
                    color: mv.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: mv.spacing.xs),
          _CartQuantityStepper(
            quantity: qty,
            isBusy: isBusy,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
        ],
      ),
    );
  }
}

class _CartQuantityStepper extends StatelessWidget {
  const _CartQuantityStepper({
    required this.quantity,
    required this.isBusy,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final bool isBusy;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    if (isBusy) {
      return SizedBox(
        width: 88,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: mv.brandPrimary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: onDecrement != null,
            onTap: onDecrement,
          ),
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$quantity',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: mv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: onIncrement != null,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final localOnTap = onTap;
    final canTap = enabled && localOnTap != null;

    return SizedBox(
      width: 30,
      height: 30,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap
              ? () {
                  HapticFeedback.lightImpact();
                  localOnTap.call();
                }
              : null,
          borderRadius: BorderRadius.circular(mv.radii.sm),
          child: Ink(
            decoration: BoxDecoration(
              color: mv.brandPrimary,
              borderRadius: BorderRadius.circular(mv.radii.sm),
            ),
            child: Center(
              child: Icon(icon, size: 18, color: MeatvoColors.white),
            ),
          ),
        ),
      ),
    );
  }
}
