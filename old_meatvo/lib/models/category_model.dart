import 'home_category_item.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? imageUrl;
  final int? productCount;
  final bool isActive;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.productCount,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory CategoryModel.fromHomeCategoryItem(HomeCategoryItem item) {
    return CategoryModel(
      id: item.id,
      name: item.name,
      imageUrl: item.imageUrl,
      productCount: item.productCount,
      isActive: true,
      sortOrder: 0,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    final name =
        (map['name'] ?? map['title'] ?? map['id'] ?? '').toString().trim();
    final id = (map['id'] ?? map['slug'] ?? name).toString();
    final rawImage =
        (map['image_url'] ?? map['imageUrl'] ?? map['icon_url'])?.toString();
    final imageUrl =
        rawImage != null && rawImage.trim().isNotEmpty ? rawImage.trim() : null;
    final rawCount = map['product_count'] ?? map['productCount'];
    int? productCount;
    if (rawCount is int) {
      productCount = rawCount;
    } else if (rawCount != null) {
      productCount = int.tryParse(rawCount.toString());
    }

    final rawActive = map['isActive'] ?? map['is_active'] ?? map['active'];
    bool isActive = true;
    if (rawActive is bool) {
      isActive = rawActive;
    } else if (rawActive != null) {
      isActive = rawActive.toString().toLowerCase() == 'true';
    }

    final rawSort = map['sortOrder'] ?? map['sort_order'];
    int sortOrder = 0;
    if (rawSort is int) {
      sortOrder = rawSort;
    } else if (rawSort != null) {
      sortOrder = int.tryParse(rawSort.toString()) ?? 0;
    }

    return CategoryModel(
      id: id,
      name: name,
      imageUrl: imageUrl,
      productCount: productCount,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }
}
