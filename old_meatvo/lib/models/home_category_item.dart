class HomeCategoryItem {
  final String id;
  final String name;
  final String? imageUrl;
  final int? productCount;

  const HomeCategoryItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.productCount,
  });
}
