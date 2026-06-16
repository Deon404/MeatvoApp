import '../../models/product_variant_model.dart';
import 'meatvo_product_card.dart';

/// Maps [ProductWithVariants] to card display values.
abstract final class ProductCardAdapter {
  static ProductVariantModel? preferredVariant(ProductWithVariants product) {
    if (product.availableVariants.isNotEmpty) {
      return product.availableVariants.first;
    }
    if (product.variants.isNotEmpty) return product.variants.first;
    return null;
  }

  static bool canAdd(ProductWithVariants product) {
    final variant = preferredVariant(product);
    if (!product.product.isAvailable) return false;
    if (variant != null) return variant.isAvailable && variant.stock > 0;
    return (product.product.stock ?? 1) > 0;
  }

  static String displayUnit(ProductWithVariants product) {
    return preferredVariant(product)?.weight ?? product.product.unit;
  }

  static double displayPrice(ProductWithVariants product) {
    return preferredVariant(product)?.price ?? product.product.finalPrice;
  }

  static double? originalPrice(ProductWithVariants product) {
    final current = displayPrice(product);
    final base = product.product;
    if (base.hasDiscount && base.price > current) return base.price;
    final discount = base.discount;
    if (discount != null && discount > 0 && discount < 100) {
      return current / (1 - (discount / 100));
    }
    return null;
  }

  static double carouselWidth(double screenWidth) => screenWidth * 0.42;

  static double carouselHeight(double screenWidth) =>
      gridCardHeight(screenWidth) * 0.95;

  static double gridCardHeight(double screenWidth) =>
      MeatvoProductCard.gridCardHeight(screenWidth);
}
