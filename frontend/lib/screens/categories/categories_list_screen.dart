import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/home_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/catalog/categories_provider.dart';
import '../../models/category_model.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/home/category_card.dart';
import 'category_products_screen.dart';

/// Category grid tab — loads via [categoriesProvider].
class CategoriesListScreen extends ConsumerStatefulWidget {
  const CategoriesListScreen({
    super.key,
    this.initialCategory,
  });

  /// When set, opens catalog filtered to this category (e.g. deep link).
  final String? initialCategory;

  @override
  ConsumerState<CategoriesListScreen> createState() =>
      _CategoriesListScreenState();
}

class _CategoriesListScreenState extends ConsumerState<CategoriesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Warm provider so the tab is not stuck on an empty frame before the first fetch.
      ref.read(categoriesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final preset = widget.initialCategory?.trim();
    if (preset != null && preset.isNotEmpty) {
      return CatalogScreen(
        initialCategory: preset,
        showBackButton: true,
      );
    }

    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Categories',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: R.fontSize(18, context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: categoriesAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _CategoriesLoadingGrid(),
          error: (err, _) => _CategoriesErrorView(
            message: err.toString(),
            onRetry: () async {
              await refreshCategoriesCache();
              ref.invalidate(categoriesProvider);
            },
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return _CategoriesErrorView(
                message: HomeStrings.categoriesLoadError,
                onRetry: () async {
                  await refreshCategoriesCache();
                  ref.invalidate(categoriesProvider);
                },
              );
            }
            return _buildCategoryList(context, ref, categories);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    WidgetRef ref,
    List<CategoryModel> categories,
  ) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await refreshCategoriesCache();
        ref.invalidate(categoriesProvider);
        await ref.read(categoriesProvider.future);
      },
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          R.sw(4, context),
          R.sh(2, context),
          R.sw(4, context),
          R.sh(2, context) + MeatvoLayout.browsingScrollBottomInset(context),
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: R.sw(3, context),
          mainAxisSpacing: R.sh(1.5, context),
          childAspectRatio: 0.85,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryCard(
            category: category,
            onTap: () {
              HapticFeedback.lightImpact();
              // Use the shared slide-right transition (same as quick
              // category from home, product detail, etc.) — keeps the
              // navigation visually consistent and avoids the platform
              // default slide-up flash that looked like a "white screen"
              // mid-transition on some Android devices.
              context.pushSlideRight<void>(
                CategoryProductsScreen(
                  categoryName: category.name,
                  categoryId: int.tryParse(category.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoriesLoadingGrid extends StatelessWidget {
  const _CategoriesLoadingGrid();

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        R.sw(4, context),
        R.sh(2, context),
        R.sw(4, context),
        R.sh(2, context) + MeatvoLayout.browsingScrollBottomInset(context),
      ),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: R.sw(3, context),
        mainAxisSpacing: R.sh(1.5, context),
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.greyLight,
        highlightColor: AppColors.white,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _CategoriesErrorView extends StatelessWidget {
  const _CategoriesErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.sw(6, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: R.sw(12, context),
              color: AppColors.textMuted,
            ),
            SizedBox(height: R.sh(2, context)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: R.fontSize(14, context),
              ),
            ),
            SizedBox(height: R.sh(1.5, context)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                HomeStrings.retryLabel,
                style: TextStyle(fontSize: R.fontSize(14, context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
