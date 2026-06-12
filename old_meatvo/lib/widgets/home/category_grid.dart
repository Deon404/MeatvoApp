import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/home_strings.dart';
import '../../models/category_model.dart';
import '../../models/home_category_item.dart';
import '../common/empty_state.dart';
import 'category_card.dart';
import 'home_inline_state_card.dart';
import 'home_layout.dart';
import 'home_section_header.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.isLoading,
    required this.errorMessage,
    required this.onViewAll,
    required this.onRetry,
    required this.onCategoryTap,
  });

  final List<HomeCategoryItem> categories;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final ValueChanged<HomeCategoryItem> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: HomeStrings.categoriesTitle,
          actionLabel: HomeStrings.viewAllLabel,
          onAction: onViewAll,
        ),
        const SizedBox(height: 12),
        if (isLoading && categories.isEmpty)
          const _CategoryGridShimmer()
        else if (errorMessage != null && categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeLayout.horizontalPadding,
            ),
            child: HomeInlineStateCard(
              icon: Icons.wifi_off_rounded,
              title: HomeStrings.connectionLostTitle,
              message: errorMessage!,
              actionLabel: HomeStrings.retryLabel,
              onAction: onRetry,
            ),
          )
        else if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeLayout.horizontalPadding,
            ),
            child: EmptyStateWidget(
              title: HomeStrings.noCategoriesTitle,
              message: HomeStrings.noCategoriesMessage,
              buttonLabel: HomeStrings.browseCatalogLabel,
              onAction: onViewAll,
              fullScreen: false,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeLayout.horizontalPadding,
            ),
            child: _buildGrid(),
          ),
      ],
    );
  }

  Widget _buildGrid() {
    final visibleCategories =
        categories.take(HomeLayout.maxHomeCategories).toList(growable: false);
    final itemCount = visibleCategories.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: HomeLayout.categoryCrossAxisCount,
        crossAxisSpacing: HomeLayout.categorySpacing,
        mainAxisSpacing: HomeLayout.categorySpacing,
        childAspectRatio: HomeLayout.categoryAspectRatio,
      ),
      itemBuilder: (context, index) {
        if (index == visibleCategories.length) {
          return _ViewAllCategoryCard(onTap: onViewAll);
        }
        final item = visibleCategories[index];
        final category = CategoryModel.fromHomeCategoryItem(item);
        return CategoryCard(
          category: category,
          onTap: () {
            HapticFeedback.lightImpact();
            onCategoryTap(item);
          },
        );
      },
    );
  }
}

class _ViewAllCategoryCard extends StatelessWidget {
  const _ViewAllCategoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: Color(0xFFCC0000),
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'View All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGridShimmer extends StatelessWidget {
  const _CategoryGridShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeLayout.horizontalPadding,
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE8E8E8),
        highlightColor: const Color(0xFFF7F7F7),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: HomeLayout.categoryCrossAxisCount,
            crossAxisSpacing: HomeLayout.categorySpacing,
            mainAxisSpacing: HomeLayout.categorySpacing,
            childAspectRatio: HomeLayout.categoryAspectRatio,
          ),
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
