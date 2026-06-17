import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../utils/media_url_resolver.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';
import '../../../models/home_category_item.dart';

/// Horizontal scrolling category chips with 56x56 containers.
class HomeCategoryRow extends StatelessWidget {
  const HomeCategoryRow({
    super.key,
    required this.categories,
    required this.isLoading,
    required this.onCategoryTap,
    required this.onViewAll,
  });

  final List<HomeCategoryItem> categories;
  final bool isLoading;
  final ValueChanged<HomeCategoryItem> onCategoryTap;
  final VoidCallback onViewAll;

  static const List<HomeCategoryItem> _defaults = [
    HomeCategoryItem(id: 'chicken', name: 'Chicken'),
    HomeCategoryItem(id: 'eggs', name: 'Eggs'),
    HomeCategoryItem(id: 'fish', name: 'Fish'),
    HomeCategoryItem(id: 'mutton', name: 'Mutton'),
  ];

  static const List<String> _activeCategories = ['chicken', 'eggs', 'egg'];
  static const List<String> _comingSoonCategories = ['fish', 'mutton'];

  /// Always show Chicken → Eggs → Fish → Mutton (API data merged in order).
  static List<HomeCategoryItem> resolve(List<HomeCategoryItem> fromApi) {
    if (fromApi.isEmpty) return _defaults;

    final byKey = <String, HomeCategoryItem>{
      for (final item in fromApi) _matchKey(item.name): item,
    };

    return _defaults.map((fallback) {
      final key = _matchKey(fallback.name);
      return byKey[key] ?? fallback;
    }).toList(growable: false);
  }

  static String _matchKey(String name) {
    final n = name.toLowerCase();
    if (n.contains('chicken')) return 'chicken';
    if (n.contains('egg')) return 'eggs';
    if (n.contains('fish')) return 'fish';
    if (n.contains('mutton')) return 'mutton';
    return n;
  }

  static bool _isActive(String categoryName) {
    final lower = categoryName.toLowerCase();
    return _activeCategories.any((active) => lower.contains(active));
  }

  static bool _isComingSoon(String categoryName) {
    final lower = categoryName.toLowerCase();
    return _comingSoonCategories.any((soon) => lower.contains(soon));
  }

  @override
  Widget build(BuildContext context) {
    final items = resolve(categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shop by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onViewAll();
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading && categories.isEmpty)
          _LoadingRow()
        else
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = items[index];
                return _CategoryChip(
                  item: category,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCategoryTap(category);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: MeatvoColors.surfaceMuted,
            highlightColor: mv.surfaceCard,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 50,
                  height: 10,
                  color: Colors.white,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.item,
    required this.onTap,
  });

  final HomeCategoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = HomeCategoryRow._isActive(item.name);
    final isComingSoon = HomeCategoryRow._isComingSoon(item.name);
    final url = MediaUrlResolver.resolve(item.imageUrl);
    final hasImage = url != null && url.isNotEmpty;

    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Opacity(
        opacity: isComingSoon ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? Colors.red : const Color(0xFFEEEEEE),
                      width: isActive ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _iconTile(context, item.name),
                          )
                        : _iconTile(context, item.name),
                  ),
                ),
                if (isComingSoon)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Soon',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                item.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconTile(BuildContext context, String name) {
    final color = _categoryColor(name);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return ColoredBox(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  static Color _categoryColor(String name) {
    final key = name.toLowerCase();
    if (key.contains('egg')) return const Color(0xFFF59E0B);
    if (key.contains('fish')) return const Color(0xFF0EA5E9);
    if (key.contains('ready') || key.contains('cook')) {
      return const Color(0xFF8B5CF6);
    }
    if (key.contains('mutton')) return const Color(0xFF10B981);
    if (key.contains('chicken')) return MeatvoColors.brandPrimary;
    return MeatvoColors.textSecondary;
  }
}
