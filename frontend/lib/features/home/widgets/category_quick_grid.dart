import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';
import '../../../design_system/tokens/meatvo_durations.dart';
import '../../../models/home_category_item.dart';
import '../../../ui/shells/section_header.dart';

/// Four quick categories in a balanced row — Chicken, Eggs, Fish, Ready to Cook.
class CategoryQuickGrid extends StatelessWidget {
  const CategoryQuickGrid({
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
    HomeCategoryItem(id: 'ready-to-cook', name: 'Ready to Cook'),
  ];

  static List<HomeCategoryItem> resolve(List<HomeCategoryItem> fromApi) {
    if (fromApi.isEmpty) return _defaults;

    final byKey = <String, HomeCategoryItem>{
      for (final item in fromApi)
        _matchKey(item.name): item,
    };

    return _defaults.map((fallback) {
      final key = _matchKey(fallback.name);
      return byKey[key] ?? fallback;
    }).toList(growable: false);
  }

  static String _matchKey(String name) {
    final n = name.toLowerCase();
    if (n.contains('egg')) return 'eggs';
    if (n.contains('fish')) return 'fish';
    if (n.contains('ready') || n.contains('cook')) return 'ready';
    if (n.contains('chicken')) return 'chicken';
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final items = resolve(categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: HomeStrings.quickCategoriesTitle,
          actionLabel: HomeStrings.viewAllLabel,
          onAction: onViewAll,
        ),
        SizedBox(height: mv.spacing.sm),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
          child: isLoading && categories.isEmpty
              ? _LoadingRow()
              : Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) SizedBox(width: mv.spacing.sm),
                      Expanded(
                        child: _CategoryCircle(
                          item: items[i],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onCategoryTap(items[i]);
                          },
                        ),
                      ),
                    ],
                  ],
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
    return Row(
      children: List.generate(
        4,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : mv.spacing.sm),
            child: Shimmer.fromColors(
              baseColor: MeatvoColors.surfaceMuted,
              highlightColor: mv.surfaceCard,
              child: Column(
                children: [
                  const AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(height: mv.spacing.xs),
                  Container(height: 10, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCircle extends StatefulWidget {
  const _CategoryCircle({required this.item, required this.onTap});

  final HomeCategoryItem item;
  final VoidCallback onTap;

  @override
  State<_CategoryCircle> createState() => _CategoryCircleState();
}

class _CategoryCircleState extends State<_CategoryCircle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: MeatvoDurations.fast,
        curve: MeatvoDurations.curve,
        child: _buildContent(context, mv),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MeatvoThemeData mv) {
    // Local smart-cast — drops the `widget.item.imageUrl!` bang and avoids
    // the "Null check operator used on a null value" crash when a category
    // is missing an image URL.
    final url = widget.item.imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mv.surfaceCard,
              boxShadow: mv.shadowSm,
            ),
            child: ClipOval(
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _iconTile(context, widget.item.name),
                    )
                  : _iconTile(context, widget.item.name),
            ),
          ),
        ),
        SizedBox(height: mv.spacing.xs),
        Text(
          widget.item.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mv.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
        ),
      ],
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
            fontSize: 24,
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
    if (key.contains('chicken')) return MeatvoColors.brandPrimary;
    return MeatvoColors.textSecondary;
  }
}
