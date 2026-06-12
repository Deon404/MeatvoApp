import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../models/product_variant_model.dart';
import '../../../ui/organisms/product_card_adapter.dart';
import '../../../ui/shells/section_header.dart';

class ReorderSection extends StatelessWidget {
  const ReorderSection({
    super.key,
    required this.products,
    required this.onProductTap,
    required this.onAdd,
  });

  final List<ProductWithVariants> products;
  final ValueChanged<ProductWithVariants> onProductTap;
  final ValueChanged<ProductWithVariants> onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final mv = context.meatvo;
    final items = products.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Order again'),
        SizedBox(height: mv.spacing.sm),
        ...items.map((product) {
          final price = ProductCardAdapter.displayPrice(product);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              mv.spacing.md,
              0,
              mv.spacing.md,
              mv.spacing.sm,
            ),
            child: Material(
              color: mv.surfaceCard,
              borderRadius: BorderRadius.circular(mv.radii.md),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onProductTap(product);
                },
                borderRadius: BorderRadius.circular(mv.radii.md),
                child: Ink(
                  padding: EdgeInsets.all(mv.spacing.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(mv.radii.md),
                    border: Border.all(color: mv.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '₹${price.toStringAsFixed(0)} · ${ProductCardAdapter.displayUnit(product)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: mv.textMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onAdd(product);
                        },
                        child: const Text('Reorder'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        SizedBox(height: mv.spacing.sm),
      ],
    );
  }
}
