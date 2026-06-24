import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/tokens/meatvo_durations.dart';
import '../../models/cart_model.dart';
import '../../utils/media_url_resolver.dart';

/// Overlapping product thumbnails for the floating cart pill (Blinkit-style).
class CartPillThumbnailStack extends StatelessWidget {
  const CartPillThumbnailStack({
    super.key,
    required this.items,
    required this.anchorKey,
    this.size = 32,
    this.overlap = 12,
  });

  final List<CartItem> items;
  final GlobalKey anchorKey;
  final double size;
  final double overlap;

  static const int _maxVisible = 2;

  /// Most recently added distinct products, oldest on the left.
  static List<CartItem> visibleItems(List<CartItem> items) {
    final seen = <String>{};
    final picked = <CartItem>[];
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      if (seen.add(item.productId)) {
        picked.add(item);
        if (picked.length >= _maxVisible) break;
      }
    }
    return picked.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final visible = visibleItems(items);
    final width = visible.isEmpty
        ? size
        : size + (visible.length - 1) * (size - overlap);

    return SizedBox(
      key: anchorKey,
      width: width,
      height: size,
      child: visible.isEmpty
          ? _ThumbCircle(
              size: size,
              borderColor: mv.brandPrimary,
              child: Icon(
                Icons.shopping_bag_outlined,
                size: size * 0.45,
                color: MeatvoColors.textMuted,
              ),
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < visible.length; i++)
                  Positioned(
                    left: i * (size - overlap),
                    child: AnimatedSwitcher(
                      duration: MeatvoDurations.fast,
                      switchInCurve: MeatvoDurations.curve,
                      switchOutCurve: MeatvoDurations.curve,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.85, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: MeatvoDurations.curve,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _ProductThumb(
                        key: ValueKey(visible[i].productId),
                        item: visible[i],
                        size: size,
                        borderColor: mv.brandPrimary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({
    super.key,
    required this.item,
    required this.size,
    required this.borderColor,
  });

  final CartItem item;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = MediaUrlResolver.resolve(item.product.primaryImageUrl);

    return _ThumbCircle(
      size: size,
      borderColor: borderColor,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: size - 4,
                height: size - 4,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(size),
                errorWidget: (_, __, ___) => _placeholder(size),
              ),
            )
          : _placeholder(size),
    );
  }

  Widget _placeholder(double size) {
    return Icon(
      Icons.image_outlined,
      size: size * 0.42,
      color: MeatvoColors.textMuted,
    );
  }
}

class _ThumbCircle extends StatelessWidget {
  const _ThumbCircle({
    required this.size,
    required this.borderColor,
    required this.child,
  });

  final double size;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(child: child),
    );
  }
}
