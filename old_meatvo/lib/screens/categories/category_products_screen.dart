import 'package:flutter/material.dart';

import '../../features/catalog/catalog_screen.dart';
import '../../utils/responsive_helper.dart';

/// Opens the product catalog with the requested category preselected.
///
/// Defensive against the historical "white screen" bug:
///   • empty/whitespace categoryName → render a visible fallback instead of
///     letting the catalog filter swallow everything and produce a blank
///     scaffold.
///   • catalog body is wrapped so that, even on the worst combination of
///     state flags, there is always *something* drawn on top of the warm
///     background.
class CategoryProductsScreen extends StatelessWidget {
  final String categoryName;
  final int? categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.categoryName,
    this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final cleanedName = categoryName.trim();
    if (cleanedName.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Category'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This category is not available right now.\nPlease try another category.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return CatalogScreen(
      initialCategory: cleanedName,
      initialCategoryId: categoryId,
      showBackButton: true,
    );
  }
}
