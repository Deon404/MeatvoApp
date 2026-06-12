import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import 'shimmer_loader.dart';

enum ProductCardLayout {
  vertical,
  horizontal,
}

/// =============================================================================
/// LEGACY ProductCard — DEPRECATED.
/// =============================================================================
///
/// **DO NOT USE THIS IN ANY CUSTOMER-FACING FLOW.**
///
/// The production-safe card is [`MeatvoProductCard`](../../ui/organisms/meatvo_product_card.dart).
/// This legacy widget remains only as a temporary shim until any stale
/// references are removed in a follow-up cleanup.  It still has the
/// known footguns that caused the catalog crashes:
///
///   • `ElevatedButton` / `OutlinedButton` inside the action area inject
///     a `_RenderInputPadding(48×48)` which throws "RenderBox was not
///     laid out" on tight rows.
///   • `Wrap`-based price row scales poorly under font-scale 200%.
///   • The internal `GestureDetector`-based stepper has NO ink ripple
///     and gives no visual feedback on rapid taps (a UX defect).
///
/// `MeatvoProductCard` fixes all three issues + has deterministic CTA
/// width that prevents `_debugRelayoutBoundaryAlreadyMarkedNeedsLayout`
/// during AnimatedSwitcher transitions.
@Deprecated(
  'Use MeatvoProductCard from lib/ui/organisms/meatvo_product_card.dart. '
  'This legacy card has documented layout footguns (IconButton, '
  '_RenderInputPadding, Wrap-based price row) and is no longer used '
  'in any customer-facing screen.',
)
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final ProductCardLayout layout;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool showWishlist;
  final bool isAdding;
  final bool isWishlisted;
  final VoidCallback? onWishlistTap;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool isPopular;
  final double? displayPrice;
  final double? originalPrice;
  final double? discountPercent;
  final String? displayUnit;

  const ProductCard({
    super.key,
    required this.product,
    this.layout = ProductCardLayout.vertical,
    this.onTap,
    this.onAdd,
    this.showWishlist = true,
    this.isAdding = false,
    this.isWishlisted = false,
    this.onWishlistTap,
    this.quantity = 0,
    this.onIncrement,
    this.onDecrement,
    this.isPopular = false,
    this.displayPrice,
    this.originalPrice,
    this.discountPercent,
    this.displayUnit,
  });

  static const double _kFallbackWidth = 160;

  bool get _isAvailable => product.isAvailable && (product.stock ?? 1) > 0;

  String get _displayUnit {
    // Local copy enables smart-cast → no `!` needed.
    final raw = displayUnit;
    if (raw != null && raw.trim().isNotEmpty) {
      return _normalizedUnit(raw);
    }
    return _normalizedUnit(product.unit);
  }

  String _normalizedUnit(String rawUnit) {
    final unit = rawUnit.trim().toLowerCase();
    if (unit.contains('piece')) return 'piece';
    if (unit.contains('pc')) return 'piece';
    if (unit.contains('kg') || unit.contains('gm') || unit.contains('g')) {
      return 'kg';
    }
    return unit.isEmpty ? 'piece' : unit;
  }

  @override
  Widget build(BuildContext context) {
    // Debug-only marker — if this fires in the logcat we know the
    // DEPRECATED card is still being mounted somewhere. The bug brief
    // explicitly asks for this so we can confirm the catalog has been
    // fully migrated to `MeatvoProductCard`.
    if (kDebugMode) {
      debugPrint(
        'Rendering LEGACY ProductCard (deprecated): ${product.id} — '
        'caller MUST migrate to MeatvoProductCard',
      );
    }
    return layout == ProductCardLayout.vertical
        ? _buildVerticalCard(context)
        : _buildHorizontalCard(context);
  }

  Widget _buildVerticalCard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.hasBoundedWidth && constraints.maxWidth > 0
                ? constraints.maxWidth
                : _kFallbackWidth;
        final imageHeight = cardWidth * 0.70;

        // SizedBox seals the width so the inner Column never receives
        // unbounded width from a careless parent (root cause of the
        // "BoxConstraints forces an infinite width" error on home rails
        // when ProductCard was dropped into a Row without Expanded).
        return SizedBox(
          width: cardWidth,
          child: _buildCardShell(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImageSection(
                  context,
                  imageHeight: imageHeight,
                  imageWidth: cardWidth,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: AppThemeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _displayUnit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppThemeColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 6),
                      _buildVerticalBottomRow(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalCard(BuildContext context) {
    return _buildCardShell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(context, imageHeight: 72, imageWidth: 72),
            const SizedBox(width: AppSpacing.sm),
            // Expanded is the only safe way to give bounded width to the
            // text column inside a Row. Without it the inner Column would
            // try to size to intrinsic width → "infinite width" crash on
            // long product names.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: AppThemeColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _displayUnit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppThemeColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildPriceRow(context),
                  const SizedBox(height: AppSpacing.sm),
                  _buildActionArea(context, horizontal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardShell(BuildContext context, {required Widget child}) {
    return Material(
      color: AppThemeColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppThemeColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: AppThemeColors.border),
            boxShadow: AppShadows.card,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context, {
    required double imageHeight,
    required double imageWidth,
  }) {
    // Local for smart-cast on the optional discount percent.
    final discount = _effectiveDiscountPercent;
    final hasDiscount = discount != null && discount > 0;

    // Sanitize URL: trim whitespace and treat empty as "no image". Calling
    // CachedNetworkImage with an empty / whitespace URL triggers a cache
    // miss that re-attempts forever and spams the network log.
    final rawUrl = product.primaryImageUrl?.trim() ?? '';
    final hasImage = rawUrl.isNotEmpty;

    Widget imageContent;
    if (!hasImage) {
      imageContent = Container(
        color: AppThemeColors.surface2,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported,
          color: AppThemeColors.textMuted,
        ),
      );
    } else {
      imageContent = CachedNetworkImage(
        imageUrl: rawUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppThemeColors.surface2,
          alignment: Alignment.center,
          child: ShimmerLoader.circle(size: imageWidth),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppThemeColors.surface2,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported,
            color: AppThemeColors.textMuted,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(AppRadius.radiusMd),
            bottom: Radius.circular(
              layout == ProductCardLayout.horizontal ? AppRadius.radiusMd : 0,
            ),
          ),
          child: SizedBox(
            height: imageHeight,
            width: imageWidth,
            child: imageContent,
          ),
        ),
        if (hasDiscount || isPopular)
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: _buildBadge(
              context,
              label: hasDiscount
                  ? '${discount.toStringAsFixed(0)}% OFF'
                  : '★ POPULAR',
              backgroundColor: hasDiscount
                  ? AppThemeColors.primary
                  : AppThemeColors.success,
            ),
          ),
        if (showWishlist)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Material(
              color: AppThemeColors.surface,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                onTap: onWishlistTap == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onWishlistTap?.call();
                      },
                customBorder: const CircleBorder(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppThemeColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.card,
                  ),
                  child: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted
                        ? AppThemeColors.primary
                        : AppThemeColors.textMuted,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required String label,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppThemeColors.white,
            ),
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    final currentPrice = displayPrice ?? product.finalPrice;
    final priceBefore = originalPrice ?? product.price;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        Text(
          '₹${currentPrice.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppThemeColors.primary,
              ),
        ),
        Text(
          '/$_displayUnit',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.textMuted,
              ),
        ),
        if (priceBefore > currentPrice)
          Text(
            '₹${priceBefore.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppThemeColors.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
          ),
      ],
    );
  }

  Widget _buildVerticalBottomRow(BuildContext context) {
    final currentPrice = displayPrice ?? product.finalPrice;
    final priceBefore = originalPrice ?? product.price;

    // Why Row + Expanded + Flexible(fit: loose):
    //   • Expanded gives the price column the leftover width (mandatory
    //     bounded width inside a Row).
    //   • The action area is naturally narrow (a 30px button or stepper);
    //     wrapping it in `Flexible(fit: loose)` lets it use its intrinsic
    //     width without overflowing on very narrow cards.
    //   • Previously this used `Flexible(child: Align(...))` which tried
    //     to stretch the Align to fill remaining width AND the Align's
    //     unconstrained child was the source of overflow warnings on
    //     small phones.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${currentPrice.toStringAsFixed(0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppThemeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (priceBefore > currentPrice)
                Text(
                  '₹${priceBefore.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppThemeColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          fit: FlexFit.loose,
          child: _buildCompactAction(context),
        ),
      ],
    );
  }

  Widget _buildCompactAction(BuildContext context) {
    if (!_isAvailable) {
      return SizedBox(
        height: 30,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppThemeColors.border),
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            ),
          ),
          child: const Text(
            'Sold',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (quantity > 0) {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          border: Border.all(color: AppThemeColors.primary),
          color: AppThemeColors.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _compactStepperButton(
              context,
              icon: Icons.remove,
              onTap: onDecrement,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '$quantity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppThemeColors.textPrimary,
                    ),
              ),
            ),
            _compactStepperButton(
              context,
              icon: Icons.add,
              onTap: onIncrement,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onAdd == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onAdd?.call();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeColors.primary,
          disabledBackgroundColor: AppThemeColors.surface2,
          disabledForegroundColor: AppThemeColors.textMuted,
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          ),
          elevation: 0,
        ),
        child: isAdding
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeColors.white,
                  ),
                ),
              )
            : Text(
                '+ Add',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppThemeColors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );
  }

  Widget _compactStepperButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap.call();
            },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppThemeColors.textMuted
              : AppThemeColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        ),
        child: Icon(
          icon,
          size: 12,
          color: AppThemeColors.white,
        ),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context, {bool horizontal = false}) {
    if (!_isAvailable) {
      return SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppThemeColors.border),
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('Sold Out'),
        ),
      );
    }

    if (quantity > 0) {
      return SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: horizontal
              ? MainAxisAlignment.start
              : MainAxisAlignment.spaceBetween,
          children: [
            _stepperButton(
              context,
              icon: Icons.remove,
              onTap: onDecrement,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '$quantity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppThemeColors.textPrimary,
                    ),
              ),
            ),
            _stepperButton(
              context,
              icon: Icons.add,
              onTap: onIncrement,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onAdd == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onAdd?.call();
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppThemeColors.primary,
          side: const BorderSide(color: AppThemeColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          ),
          minimumSize: const Size.fromHeight(44),
        ),
        child: isAdding
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeColors.primary,
                  ),
                ),
              )
            : Text(
                '+ Add',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppThemeColors.primary,
                    ),
              ),
      ),
    );
  }

  Widget _stepperButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap.call();
                },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: onTap == null
                  ? AppThemeColors.textMuted
                  : AppThemeColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppThemeColors.white,
            ),
          ),
        ),
      ),
    );
  }

  double? get _effectiveDiscountPercent {
    // Local copies avoid `!` and make smart-cast work cleanly.
    final explicit = discountPercent;
    if (explicit != null && explicit > 0) return explicit;
    final fromProduct = product.discount;
    if (fromProduct != null && fromProduct > 0) return fromProduct;
    return null;
  }
}
