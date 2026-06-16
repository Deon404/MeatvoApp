import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/tokens/meatvo_colors.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_durations.dart';
import '../../../models/home_category_item.dart';
import '../../../ui/shells/section_header.dart';

class CategoryChipRow extends StatelessWidget {
  const CategoryChipRow({
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

  static const double chipSize = 72;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: HomeStrings.categoriesTitle,
          actionLabel: HomeStrings.viewAllLabel,
          onAction: onViewAll,
        ),
        SizedBox(height: mv.spacing.sm),
        if (isLoading && categories.isEmpty)
          SizedBox(
            height: chipSize + 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(width: mv.spacing.md),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: MeatvoColors.surfaceMuted,
                highlightColor: mv.surfaceCard,
                child: Column(
                  children: [
                    Container(
                      width: chipSize,
                      height: chipSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(height: mv.spacing.xs),
                    Container(width: 52, height: 10, color: Colors.white),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: chipSize + 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
              itemCount: categories.take(8).length + 1,
              separatorBuilder: (_, __) => SizedBox(width: mv.spacing.md),
              itemBuilder: (context, index) {
                final items = categories.take(8).toList(growable: false);
                if (index == items.length) {
                  return _ViewAllChip(onTap: onViewAll);
                }
                final item = items[index];
                return _CategoryCircle(
                  item: item,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCategoryTap(item);
                  },
                );
              },
            ),
          ),
      ],
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
    // Smart-cast local: avoids the `widget.item.imageUrl!` bangs and keeps
    // the chip rendering even if a model rebuild momentarily nulls the URL.
    final imageUrl = widget.item.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: MeatvoDurations.fast,
        curve: MeatvoDurations.curve,
        child: SizedBox(
          width: CategoryChipRow.chipSize + 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: CategoryChipRow.chipSize,
                height: CategoryChipRow.chipSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mv.surfaceCard,
                  border: Border.all(color: mv.border, width: 1.5),
                  boxShadow: mv.shadowSm,
                ),
                child: ClipOval(
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _iconFallback(context, widget.item.name),
                        )
                      : _iconFallback(context, widget.item.name),
                ),
              ),
              SizedBox(height: mv.spacing.xs),
              Text(
                widget.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconFallback(BuildContext context, String name) {
    final mv = context.meatvo;
    return ColoredBox(
      color: MeatvoColors.primaryLight,
      child: Center(
        child: Icon(_iconFor(name), color: mv.brandPrimary, size: 30),
      ),
    );
  }

  IconData _iconFor(String name) {
    final key = name.toLowerCase();
    if (key.contains('egg')) return Icons.egg_alt_outlined;
    if (key.contains('fish')) return Icons.set_meal_outlined;
    if (key.contains('mutton')) return Icons.restaurant_outlined;
    if (key.contains('chicken')) return Icons.egg_outlined;
    return Icons.kebab_dining_outlined;
  }
}

class _ViewAllChip extends StatelessWidget {
  const _ViewAllChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: CategoryChipRow.chipSize + 4,
        child: Column(
          children: [
            Container(
              width: CategoryChipRow.chipSize,
              height: CategoryChipRow.chipSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mv.brandPrimary.withValues(alpha: 0.06),
                border: Border.all(
                  color: mv.brandPrimary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: mv.brandPrimary,
                size: 28,
              ),
            ),
            SizedBox(height: mv.spacing.xs),
            Text(
              'All',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mv.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
