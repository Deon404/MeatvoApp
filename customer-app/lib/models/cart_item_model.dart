import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  final int quantity;
  final int weight;

  const CartItemModel({
    required this.product,
    required this.quantity,
    required this.weight,
  });

  double get total => product.price * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    int? weight,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
    );
  }
}
