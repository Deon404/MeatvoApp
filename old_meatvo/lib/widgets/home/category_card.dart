import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../constants/category_images.dart';
import '../../core/constants/app_constants.dart';
import '../../models/category_model.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (category.productCount != null)
                      Text(
                        '${category.productCount} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              if (!category.isActive)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.greyMedium.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = CategoryImages.resolveUrl(
      category.imageUrl,
      category.name,
    );
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.greyLight,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _buildFallbackTile(),
      );
    }

    return _buildFallbackTile();
  }

  Widget _buildFallbackTile() {
    final color = _accentColor(category.name);
    final initial =
        category.name.trim().isNotEmpty ? category.name.trim()[0].toUpperCase() : '?';

    return Container(
      color: _getCardColor(category.name),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 32,
        backgroundColor: color.withValues(alpha: 0.20),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Color _accentColor(String name) {
    final key = name.toLowerCase();
    if (key.contains('egg')) return AppColors.warning;
    if (key.contains('fish') || key.contains('seafood')) {
      return AppColors.bluePrimary;
    }
    if (key.contains('mutton') ||
        key.contains('lamb') ||
        key.contains('goat')) {
      return AppColors.success;
    }
    if (key.contains('chicken')) return AppColors.primary;
    return AppColors.textSecondary;
  }

  Color _getCardColor(String name) {
    switch (name.toLowerCase()) {
      case 'chicken':
        return AppColors.primaryLight;
      case 'mutton':
        return const Color(0xFFF0FFF0);
      case 'fish':
        return const Color(0xFFF0F8FF);
      case 'eggs':
        return const Color(0xFFFFFAF0);
      default:
        if (name.toLowerCase().contains('egg')) {
          return const Color(0xFFFFFAF0);
        }
        if (name.toLowerCase().contains('fish') ||
            name.toLowerCase().contains('seafood')) {
          return const Color(0xFFF0F8FF);
        }
        if (name.toLowerCase().contains('mutton') ||
            name.toLowerCase().contains('lamb')) {
          return const Color(0xFFF0FFF0);
        }
        if (name.toLowerCase().contains('chicken')) {
          return AppColors.primaryLight;
        }
        return AppColors.greyLight;
    }
  }
}
