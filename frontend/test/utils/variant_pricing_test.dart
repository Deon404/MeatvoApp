import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/product_model.dart';
import '../../lib/models/product_variant_model.dart';
import '../../lib/utils/variant_pricing.dart';

void main() {
  group('VariantPricing', () {
    final product = ProductModel(
      id: '1',
      name: 'Chilli Cut',
      price: 600,
      unit: 'kg',
      isAvailable: true,
    );

    test('scales per-kg price for 500g variant', () {
      final variant = ProductVariantModel(
        id: '1_500',
        productId: '1',
        weight: '500g',
        weightValue: 0.5,
        price: 600,
      );

      expect(
        VariantPricing.salePrice(variant: variant, product: product),
        300,
      );
    });

    test('parses weight value from label when missing', () {
      expect(
        VariantPricing.parseWeightValue(null, '500g'),
        0.5,
      );
      expect(
        VariantPricing.weightGramsFromVariant(
          ProductVariantModel(
            id: '1_500',
            productId: '1',
            weight: '500g',
            weightValue: 0.5,
            price: 300,
          ),
        ),
        500,
      );
    });
  });
}
