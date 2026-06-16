import 'package:flutter/material.dart';

import '../../models/product_variant_model.dart';
import 'product_section.dart';

export 'product_section.dart' show ProductSection, ProductSectionLayout;

/// =============================================================================
/// DEPRECATED — use the new `ProductCarouselSection` in
/// `features/home/widgets/product_carousel_section.dart`.
/// =============================================================================
@Deprecated(
  'Use ProductCarouselSection + MeatvoProductCard. '
  'ProductListSection wraps the deprecated ProductSection / ProductCard '
  'stack and must not be used in any customer-facing screen.',
)
// ignore_for_file: deprecated_member_use_from_same_package
class ProductListSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ProductWithVariants> products;
  final void Function(ProductWithVariants product)? onProductTap;
  final VoidCallback? onViewAll;
  final bool showViewAll;
  final ProductSectionLayout layout;
  final double gridChildAspectRatio;

  const ProductListSection({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
    this.onProductTap,
    this.onViewAll,
    this.showViewAll = false,
    this.layout = ProductSectionLayout.carousel,
    this.gridChildAspectRatio = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return ProductSection.browse(
      title: title,
      products: products,
      subtitle: subtitle,
      layout: layout,
      gridChildAspectRatio: gridChildAspectRatio,
      showViewAll: showViewAll,
      onViewAll: onViewAll,
      onProductTap: onProductTap,
    );
  }
}
