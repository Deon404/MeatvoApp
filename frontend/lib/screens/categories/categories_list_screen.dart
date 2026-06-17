import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/catalog_screen.dart';

/// Categories bottom-nav tab — inline swipeable catalog browser.
class CategoriesListScreen extends ConsumerWidget {
  const CategoriesListScreen({
    super.key,
    this.initialCategory,
  });

  /// When set, opens catalog filtered to this category (e.g. deep link).
  final String? initialCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = initialCategory?.trim();
    if (preset != null && preset.isNotEmpty) {
      return CatalogScreen(
        initialCategory: preset,
        showBackButton: true,
      );
    }

    return const CatalogScreen(showBackButton: false);
  }
}
