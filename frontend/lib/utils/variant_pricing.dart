import '../models/product_model.dart';
import '../models/product_variant_model.dart';

/// Variant weight labels and per-line sale prices (weight × ₹/kg).
abstract final class VariantPricing {
  static double parseWeightValue(dynamic weightValue, dynamic weightLabel) {
    if (weightValue != null) {
      if (weightValue is num) {
        final v = weightValue.toDouble();
        if (v > 0) {
          if (v >= 10) return v / 1000;
          return v;
        }
      }
      if (weightValue is String) {
        final parsed = double.tryParse(weightValue.trim());
        if (parsed != null && parsed > 0) {
          if (parsed >= 10) return parsed / 1000;
          return parsed;
        }
      }
    }
    return _weightValueFromLabel(weightLabel?.toString() ?? '');
  }

  static double _weightValueFromLabel(String label) {
    final s = label.trim().toLowerCase();
    if (s.isEmpty) return 1.0;

    final kgMatch = RegExp(r'([\d.]+)\s*kg').firstMatch(s);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1)!) ?? 1.0;
    }

    final gMatch = RegExp(r'(\d+)\s*g').firstMatch(s);
    if (gMatch != null) {
      return (int.tryParse(gMatch.group(1)!) ?? 500) / 1000;
    }

    return 1.0;
  }

  static int? weightGramsFromVariant(ProductVariantModel? variant) {
    if (variant == null) return null;
    if (variant.weightValue > 0) {
      return (variant.weightValue * 1000).round();
    }
    final gMatch = RegExp(r'(\d+)\s*g', caseSensitive: false)
        .firstMatch(variant.weight);
    if (gMatch != null) {
      return int.tryParse(gMatch.group(1)!);
    }
    final kgMatch = RegExp(r'([\d.]+)\s*kg', caseSensitive: false)
        .firstMatch(variant.weight);
    if (kgMatch != null) {
      final kg = double.tryParse(kgMatch.group(1)!);
      if (kg != null) return (kg * 1000).round();
    }
    return null;
  }

  static double basePricePerKg(ProductModel product) {
    if (product.finalPrice > 0) return product.finalPrice;
    return product.price;
  }

  /// Line price for one pack at the selected weight.
  static double salePrice({
    required ProductVariantModel variant,
    required ProductModel product,
  }) {
    final perKg = basePricePerKg(product);
    final weightKg = variant.weightValue > 0
        ? variant.weightValue
        : _weightValueFromLabel(variant.weight);
    final scaled = (perKg * weightKg * 100).round() / 100;

    if (variant.price <= 0) return scaled;

    // Admin/API sometimes stores ₹/kg on every variant row.
    if ((variant.price - perKg).abs() < 0.01 && weightKg < 1.0) {
      return scaled;
    }
    if (variant.price < perKg * 0.99) return variant.price;
    if ((variant.price - scaled).abs() < 1.5) return variant.price;
    return scaled;
  }
}
