import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../models/product_variant_model.dart';
import '../../../ui/shells/section_header.dart';

/// Popular combo cards with savings badge (uses featured products as data source).
class ComboDealsSection extends StatelessWidget {
  const ComboDealsSection({
    super.key,
    required this.products,
    required this.onComboTap,
  });

  final List<ProductWithVariants> products;
  final ValueChanged<ProductWithVariants> onComboTap;

  @override
  Widget build(BuildContext context) {
    if (products.length < 2) return const SizedBox.shrink();

    final mv = context.meatvo;
    final combos = <List<ProductWithVariants>>[];
    for (var i = 0; i < products.length - 1 && combos.length < 4; i += 2) {
      combos.add([products[i], products[i + 1]]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Popular combos'),
        SizedBox(height: mv.spacing.sm),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
            itemCount: combos.length,
            separatorBuilder: (_, __) => SizedBox(width: mv.spacing.sm),
            itemBuilder: (context, index) {
              final pair = combos[index];
              final savings = _estimateSavings(pair);
              return _ComboCard(
                title: '${pair[0].product.name.split(' ').first} + ${pair[1].product.name.split(' ').first}',
                savings: savings,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onComboTap(pair[0]);
                },
              );
            },
          ),
        ),
        SizedBox(height: mv.spacing.md),
      ],
    );
  }

  int _estimateSavings(List<ProductWithVariants> pair) {
    final total = pair.fold<double>(
      0,
      (sum, p) => sum + (p.product.finalPrice),
    );
    return (total * 0.08).round().clamp(20, 150);
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({
    required this.title,
    required this.savings,
    required this.onTap,
  });

  final String title;
  final int savings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return Material(
      color: mv.surfaceCard,
      borderRadius: BorderRadius.circular(mv.radii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(mv.radii.lg),
        child: Ink(
          width: 200,
          padding: EdgeInsets.all(mv.spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mv.radii.lg),
            border: Border.all(color: mv.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mv.brandPrimary.withValues(alpha: 0.06),
                mv.surfaceCard,
              ],
            ),
            boxShadow: mv.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: mv.spacing.xs,
                  vertical: mv.spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: mv.brandPrimary,
                  borderRadius: BorderRadius.circular(mv.radii.pill),
                ),
                child: Text(
                  'Save ₹$savings',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: mv.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Add combo',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: mv.brandPrimary,
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
