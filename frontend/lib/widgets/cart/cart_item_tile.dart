import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/cart_model.dart';
import '../../theme/app_theme.dart';
import 'premium_cart_card.dart';

class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.emojiFallback,
    this.isBusy = false,
  });

  final CartItem item;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final String emojiFallback;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final qty = item.quantity.round();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(
            imageUrl: item.product.primaryImageUrl,
            emoji: emojiFallback,
          ),
          const SizedBox(width: 12),
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
                    color: const Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B6B6B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${(item.unitPrice * qty).toStringAsFixed(0)}',
                  maxLines: 1,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFC8102E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.emoji,
  });

  final String? imageUrl;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final safeUrl = imageUrl ?? '';
    final hasUrl = safeUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        height: 70,
        child: !hasUrl
            ? _placeholder(emoji)
            : CachedNetworkImage(
                imageUrl: safeUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(emoji),
                errorWidget: (_, __, ___) => _placeholder(emoji),
              ),
      ),
    );
  }

  Widget _placeholder(String emoji) {
    return Container(
      color: AppThemeColors.surface2,
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
    if (isBusy) {
      return const SizedBox(
        width: 88,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
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
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 15,
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
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFC8102E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
