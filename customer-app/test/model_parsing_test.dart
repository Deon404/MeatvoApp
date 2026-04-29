import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/models/product_model.dart';
import 'package:customer_app/models/user_model.dart';

void main() {
  group('Model parsing', () {
    test('UserModel parses expected fields', () {
      final user = UserModel.fromJson({
        'id': 11,
        'phone': '9876543210',
        'role': 'CUSTOMER',
        'name': 'Sadiq',
      });

      expect(user.id, 11);
      expect(user.phone, '9876543210');
      expect(user.role, 'CUSTOMER');
      expect(user.name, 'Sadiq');
    });

    test('ProductModel parses numeric and list fields', () {
      final product = ProductModel.fromJson({
        'id': 5,
        'name': 'Chicken Curry Cut',
        'description': 'Fresh',
        'category_id': 2,
        'category_name': 'Chicken',
        'display_price': 299,
        'image_url': 'https://example.com/p.png',
        'stock': 14,
        'weight_variants': [500, 1000],
      });

      expect(product.id, 5);
      expect(product.price, 299);
      expect(product.weightVariants, [500, 1000]);
      expect(product.stock, 14);
    });
  });
}
