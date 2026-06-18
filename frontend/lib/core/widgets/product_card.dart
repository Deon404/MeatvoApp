import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.weight,
    required this.price,
    this.imageUrl,
    this.quantity = 0,
    this.showWishlistHeart = false,
    this.isWishlisted = false,
    this.onTap,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
    this.onWishlistTap,
  });

  final String name;
  final String weight;
  final String price;
  final String? imageUrl;
  final int quantity;
  final bool showWishlistHeart;
  final bool isWishlisted;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onWishlistTap;

  static const double cardHeight = 180;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  static const Duration _scaleDuration = Duration(milliseconds: 150);

  double _ctaScale = 1;

  Future<void> _pulseAdd(VoidCallback? action) async {
    setState(() => _ctaScale = 0.92);
    action?.call();
    await Future<void>.delayed(_scaleDuration);
    if (!mounted) return;
    setState(() => _ctaScale = 1);
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = ProductCard.cardHeight * 0.55;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: ProductCard.cardHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(imageUrl: widget.imageUrl),
                  if (widget.showWishlistHeart)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Material(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: widget.onWishlistTap,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              widget.isWishlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: widget.isWishlisted
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.weight,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.price,
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AnimatedScale(
                          scale: _ctaScale,
                          duration: _scaleDuration,
                          curve: Curves.easeOut,
                          child: _AddOrQuantityControl(
                            quantity: widget.quantity,
                            onAdd: () => _pulseAdd(widget.onAdd),
                            onIncrement: widget.onIncrement,
                            onDecrement: widget.onDecrement,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return ColoredBox(
        color: AppColors.divider,
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          size: 32,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => ColoredBox(
        color: AppColors.divider,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: AppColors.divider,
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          size: 28,
        ),
      ),
    );
  }
}

class _AddOrQuantityControl extends StatelessWidget {
  const _AddOrQuantityControl({
    required this.quantity,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    if (quantity <= 0) {
      return _AddButton(onPressed: onAdd);
    }

    return _QuantityStepper(
      quantity: quantity,
      onDecrement: onDecrement,
      onIncrement: onIncrement,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.add_rounded,
            color: AppColors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    this.onDecrement,
    this.onIncrement,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIconButton(
            icon: Icons.remove,
            onPressed: onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              '$quantity',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          _StepIconButton(
            icon: Icons.add,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepIconButton extends StatelessWidget {
  const _StepIconButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs + 2),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
