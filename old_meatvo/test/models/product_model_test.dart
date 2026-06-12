import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/models/product_model.dart';

/// Unit tests for ProductModel
void main() {
  group('ProductModel', () {
    test('fromJson should create ProductModel from valid JSON', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Product',
        'description': 'Test Description',
        'category_name': 'chicken',
        'price': 100.0,
        'discount': 10.0,
        'stock': 50.0,
        'image_url': 'https://example.com/image.jpg',
        'unit': 'kg',
        'is_available': true,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, 'test-id');
      expect(product.name, 'Test Product');
      expect(product.description, 'Test Description');
      expect(product.categoryName, 'chicken');
      expect(product.price, 100.0);
      expect(product.discount, 10.0);
      expect(product.stock, 50.0);
      expect(product.imageUrl, 'https://example.com/image.jpg');
      expect(product.unit, 'kg');
      expect(product.isAvailable, true);
    });

    test('finalPrice should calculate correctly with percentage discount', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        price: 100.0,
        discount: 10.0, // 10% discount
      );

      // finalPrice = price - (price * discount / 100)
      // = 100 - (100 * 10 / 100) = 100 - 10 = 90
      expect(product.finalPrice, 90.0);
    });

    test('finalPrice should equal price when discount is null', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        price: 100.0,
        discount: null,
      );

      expect(product.finalPrice, 100.0);
    });

    test('finalPrice should equal price when discount is 0', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        price: 100.0,
        discount: 0.0,
      );

      expect(product.finalPrice, 100.0);
    });

    test('hasDiscount should return true when discount > 0', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        price: 100.0,
        discount: 10.0,
      );

      expect(product.hasDiscount, true);
    });

    test('hasDiscount should return false when discount is null', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        price: 100.0,
        discount: null,
      );

      expect(product.hasDiscount, false);
    });

    test('hasDiscount should return false when discount is 0', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        price: 100.0,
        discount: 0.0,
      );

      expect(product.hasDiscount, false);
    });

    test('toJson should convert ProductModel to JSON correctly', () {
      final product = ProductModel(
        id: 'test-id',
        name: 'Test Product',
        description: 'Test Description',
        price: 100.0,
        categoryName: 'chicken',
        imageUrl: 'https://example.com/image.jpg',
        unit: 'kg',
        stock: 50.0,
        isAvailable: true,
        discount: 10.0,
      );

      final json = product.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Product');
      expect(json['description'], 'Test Description');
      expect(json['price'], 100.0);
      expect(json['category_name'], 'chicken');
      expect(json['image_url'], 'https://example.com/image.jpg');
      expect(json['unit'], 'kg');
      expect(json['stock'], 50.0);
      expect(json['is_available'], true);
      expect(json['discount'], 10.0);
    });

    test('copyWith should create a copy with updated fields', () {
      final original = ProductModel(
        id: 'test-id',
        name: 'Original Product',
        price: 100.0,
      );

      final updated = original.copyWith(
        name: 'Updated Product',
        price: 150.0,
      );

      expect(updated.id, 'test-id'); // Unchanged
      expect(updated.name, 'Updated Product'); // Changed
      expect(updated.price, 150.0); // Changed
    });
  });
}

