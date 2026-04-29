class ProductModel {
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final String categoryName;
  final double price;
  final String imageUrl;
  final int stock;
  final List<int> weightVariants;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.imageUrl,
    required this.stock,
    required this.weightVariants,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final variantsRaw = (json['weight_variants'] ?? const <dynamic>[]) as List<dynamic>;
    return ProductModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      categoryId: ((json['category_id'] ?? 0) as num).toInt(),
      categoryName: (json['category_name'] ?? '').toString(),
      price: ((json['display_price'] ?? json['price'] ?? 0) as num).toDouble(),
      imageUrl: (json['image_url'] ?? '').toString(),
      stock: ((json['stock'] ?? 0) as num).toInt(),
      weightVariants: variantsRaw.map((e) => (e as num).toInt()).toList(),
    );
  }
}
