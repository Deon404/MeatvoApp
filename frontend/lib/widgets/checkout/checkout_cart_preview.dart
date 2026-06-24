import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/cart_model.dart';
import 'checkout_section_header.dart';

/// Compact cart item preview on checkout — flat layout, no nested cards.
class CheckoutCartPreview extends StatelessWidget {
  const CheckoutCartPreview({
    super.key,
    required this.items,
    this.maxVisible = 3,
  });

  final List<CartItem> items;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final visible = items.take(maxVisible).toList();
    final hiddenCount = items.length - visible.length;
    final isSingleItem = items.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionHeader(
          title: 'Order summary',
          subtitle: isSingleItem
              ? null
              : '${items.length} ${items.length == 1 ? 'item' : 'items'}',
        ),
        if (isSingleItem)
          _CompactItemLine(item: visible.first)
        else ...[
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: mv.spacing.xs),
                child: Divider(height: 1, color: mv.border),
              ),
            _CheckoutItemRow(item: visible[i]),
          ],
          if (hiddenCount > 0) ...[
            SizedBox(height: mv.spacing.xs),
            Text(
              '+ $hiddenCount more ${hiddenCount == 1 ? 'item' : 'items'}',
              style: textTheme.bodySmall?.copyWith(
                color: mv.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Single-item checkout: one compact line, no image or card.
class _CompactItemLine extends StatelessWidget {
  const _CompactItemLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final product = item.product;
    final qty = item.quantity.truncateToDouble() == item.quantity
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: mv.spacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.totalPrice.toStringAsFixed(0)}',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$qty ${item.unit}',
              style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final product = item.product;
    final imageUrl = product.primaryImageUrl;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(mv.radii.sm),
          child: Container(
            width: 40,
            height: 40,
            color: mv.surfaceWarm,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_not_supported_outlined,
                      color: mv.textMuted,
                      size: 18,
                    ),
                  )
                : Icon(
                    Icons.restaurant_outlined,
                    color: mv.textMuted,
                    size: 18,
                  ),
          ),
        ),
        SizedBox(width: mv.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
              ),
            ],
          ),
        ),
        Text(
          '₹${item.totalPrice.toStringAsFixed(0)}',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
