import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../utils/product_unit_helper.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/cart_model.dart';
import '../../models/product_variant_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/api_service.dart' show RealtimeChannel;
import '../../services/cart_service.dart';
import '../../services/cart_sync_subscription.dart';
import '../../services/product_service.dart';
import '../../screens/cart/cart_screen.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/cart/floating_cart_bar.dart';
import '../../widgets/animations/hero_image_widget.dart';
import '../../widgets/cached_image_widget.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/shimmer_loader.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';
import '../../providers/store_settings_provider.dart';
import '../../ui/organisms/product_card_bindings.dart';
import '../../utils/ordering_gate.dart';
import '../../widgets/store/store_closed_banner.dart';
import '../../widgets/store/store_closed_sheet.dart';
import '../../theme/app_theme.dart' show AppThemeColors;

/// Product Detail Screen - Full product information with variants and add to cart
class ProductDetailScreen extends ConsumerStatefulWidget {
  static const _imageHeight = 260.0;
  final String productId;
  final ProductWithVariants? initialProduct;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();

  ProductWithVariants? _product;
  CartModel _cart = CartModel();
  RealtimeChannel? _productUpdatesChannel;
  ProductVariantModel? _selectedVariant;
  List<ProductWithVariants> _relatedProducts = [];
  ProviderSubscription<AsyncValue<ProductWithVariants?>>? _productSubscription;

  bool _isLoadingRelated = false;
  bool _isDescriptionExpanded = false;
  int _quantity = 1;
  double _averageRating = 0.0;
  int _reviewCount = 0;
  late final CartSyncSubscription _cartSync;

  @override
  void initState() {
    super.initState();
    _cartSync = CartSyncSubscription((cart) {
      if (!mounted) return;
      setState(() {
        _cart = cart;
        if (_product != null) {
          _quantity = (_currentCartItem?.quantity.round() ?? 1).clamp(1, 99);
        }
      });
    });
    _subscribeToProductUpdates();

    if (widget.initialProduct != null) {
      _applyProviderProduct(widget.initialProduct!);
    }

    _productSubscription = ref.listenManual(
      productDetailProvider(widget.productId),
      (previous, next) {
        next.when(
          data: (product) {
            if (product != null && mounted) {
              _applyProviderProduct(product);
            }
          },
          loading: () {},
          error: (_, __) {
            if (mounted) {
              setState(() {
                _product = null;
              });
            }
          },
        );
      },
      fireImmediately: true,
    );
  }

  Future<void> _applyProviderProduct(ProductWithVariants product) async {
    if (!mounted) return;

    setState(() {
      _product = product;
      _selectedVariant = _defaultVariant(product);
    });

    final cart = await _cartService.getCart().catchError((_) => CartModel());
    if (!mounted) return;

    setState(() {
      _cart = cart;
      _quantity = (_currentCartItem?.quantity.round() ?? 1).clamp(1, 99);
    });

    _loadProductRating();
    _loadRelatedProducts();
  }

  @override
  void dispose() {
    _cartSync.dispose();
    _productSubscription?.close();
    _productUpdatesChannel?.unsubscribe();
    _productUpdatesChannel = null;
    super.dispose();
  }

  void _subscribeToProductUpdates() {
    _productUpdatesChannel = _productService.subscribeToProductUpdates(
      onProductUpdated: _handleRealtimeProductChange,
      onProductInserted: _handleRealtimeProductChange,
      onProductDeleted: _handleRealtimeProductChange,
    );
  }

  void _handleRealtimeProductChange() {
    if (!mounted) return;
    _loadProduct(forceRefresh: true);
  }

  Future<void> _loadProduct({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await ProductService.clearProductCache();
    }
    ref.invalidate(productDetailProvider(widget.productId));
  }

  ProductVariantModel? _defaultVariant(ProductWithVariants product) {
    if (product.availableVariants.isNotEmpty) {
      return product.availableVariants.first;
    }
    if (product.variants.isNotEmpty) {
      return product.variants.first;
    }
    return null;
  }

  Future<void> _toggleWishlist() async {
    HapticFeedback.lightImpact();
    final wasInWishlist =
        ref.read(wishlistProvider).contains(widget.productId);

    try {
      await ref.read(wishlistProvider.notifier).toggle(widget.productId);

      if (!mounted) return;
      final isInWishlist = !wasInWishlist;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInWishlist ? 'Added to wishlist' : 'Removed from wishlist',
          ),
          backgroundColor: isInWishlist
              ? AppThemeColors.success
              : AppThemeColors.textPrimary,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update wishlist: $e'),
          backgroundColor: AppThemeColors.error,
        ),
      );
    }
  }
  Future<void> _loadProductRating() async {
    if (_product == null) return;
    try {
      final ratingData = await _productService.getProductRating(widget.productId);
      if (!mounted) return;
      setState(() {
        _averageRating = (ratingData['averageRating'] as num?)?.toDouble() ?? 0.0;
        _reviewCount = ratingData['reviewCount'] as int? ?? 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _averageRating = 0.0;
        _reviewCount = 0;
      });
    }
  }

  Future<void> _loadRelatedProducts() async {
    // Local capture so we drop the `_product!` bang. Dart cannot
    // smart-cast `_product` (an instance field) across the awaits below,
    // and a sibling rebuild that nulls the field mid-await would crash
    // with "Null check operator used on a null value".
    final localProduct = _product;
    if (localProduct == null) return;

    if (mounted) {
      setState(() {
        _isLoadingRelated = true;
      });
    }

    try {
      final related = await _productService.getRelatedProducts(
        productId: widget.productId,
        category: localProduct.product.categoryName ?? '',
        limit: 6,
      );
      if (!mounted) return;
      setState(() {
        _relatedProducts = related;
        _isLoadingRelated = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRelated = false;
      });
    }
  }

  CartItem? get _currentCartItem {
    final productId = _product?.product.id;
    if (productId == null) return null;
    // Variant-aware cart lookup: find by both productId and current variantId
    final variantId = _selectedVariant?.id;
    return _cart.findItemByProductAndVariant(productId, variantId);
  }

  bool get _isInStock {
    // Capture both fields into locals so smart-cast promotes them to
    // non-null. Previously the four `!` bangs here threw "Null check
    // operator used on a null value" if a websocket product-update
    // landed exactly between the guard and the read.
    final product = _product;
    if (product == null) return false;
    final variant = _selectedVariant;
    if (variant != null) {
      return variant.isAvailable && variant.stock > 0;
    }
    return product.product.isAvailable && (product.product.stock ?? 0) > 0;
  }

  String get _displayUnit => _displayUnitFor(_product?.product.unit);

  String _displayUnitFor(String? rawUnit) =>
      ProductUnitHelper.normalizeDisplayUnit(rawUnit);

  Future<void> _saveCart() async {
    final localProduct = _product;
    if (localProduct == null || !_isInStock) return;

    final storeStatus = ref.read(storeSettingsSyncProvider);
    final cartItem = _currentCartItem;
    final previousQty = cartItem?.quantity.round() ?? 0;
    if (!storeStatus.isAcceptingOrders && _quantity > previousQty) {
      await StoreClosedSheet.show(context, storeStatus);
      if (mounted && cartItem != null) {
        setState(() => _quantity = previousQty);
      }
      return;
    }

    final product = localProduct.product;
    final selectedVariantId = _selectedVariant?.id;
    final selectedUnit = ProductUnitHelper.isPieceUnit(product.unit)
        ? ProductUnitHelper.normalizeDisplayUnit(product.unit)
        : (_selectedVariant?.weight ?? product.unit);
    final variant = _selectedVariant;

    final optimisticCart = _cartService.buildOptimisticCart(
      current: _cart,
      product: product,
      productId: product.id,
      nextQuantity: _quantity,
      variantId: selectedVariantId,
      variantPrice: variant?.price,
      unit: selectedUnit,
    );
    _cartService.applyOptimisticCart(optimisticCart);
    if (mounted) {
      setState(() => _cart = optimisticCart);
    }

    try {
      final cartItemId = cartItem?.itemId;
      if (cartItem != null && cartItemId != null && cartItemId.isNotEmpty) {
        final hasVariantChanged = cartItem.variantId != selectedVariantId;
        if (hasVariantChanged) {
          await _cartService.removeFromCart(cartItemId);
          await _cartService.addToCart(
            product.id,
            _quantity,
            unit: selectedUnit,
            variantId: selectedVariantId,
          );
        } else {
          await _cartService.updateCartItem(cartItemId, _quantity);
        }
      } else {
        await _cartService.addToCart(
          product.id,
          _quantity,
          unit: selectedUnit,
          variantId: selectedVariantId,
        );
      }

      final refreshedCart = await _cartService.getCart().catchError((_) => _cart);
      if (!mounted) return;
      setState(() {
        _cart = refreshedCart;
      });
    } catch (e) {
      final refreshedCart = await _cartService.getCart().catchError((_) => _cart);
      if (!mounted) return;
      setState(() => _cart = refreshedCart);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update cart: $e'),
          backgroundColor: AppThemeColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final ProductWithVariants? displayProduct = productAsync.hasValue
        ? productAsync.value
        : (widget.initialProduct ?? _product);
    final showFullShimmer = displayProduct == null && productAsync.isLoading;
    final hasBottomBar = displayProduct != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppThemeColors.background,
      appBar: showFullShimmer
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: mv.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: showFullShimmer
                ? const ShimmerLoader.productDetail()
                : productAsync.when(
                    loading: () {
                      final fallback = widget.initialProduct ?? _product;
                      if (fallback != null) {
                        return _buildProductDetails(fallback);
                      }
                      return const ShimmerLoader.productDetail();
                    },
                    error: (err, _) {
                      final fallback = widget.initialProduct ?? _product;
                      if (fallback != null) {
                        return _buildProductDetails(fallback);
                      }
                      return ErrorStateWidget(
                        title: 'Failed to load product',
                        message: err.toString().replaceFirst('Exception: ', ''),
                        buttonLabel: 'Retry',
                        icon: Icons.error_outline,
                        onRetry: () =>
                            ref.refresh(productDetailProvider(widget.productId)),
                      );
                    },
                    data: (product) {
                      if (product == null) {
                        return const EmptyStateWidget(
                          title: 'Product not found',
                          message:
                              'Try exploring other fresh picks from the catalogue.',
                        );
                      }
                      return _buildProductDetails(product);
                    },
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MeatvoLayout.productDetailFloatingCartBottom(
              context,
              hasBottomBar: hasBottomBar,
            ),
            child: FloatingCartBar(
              onViewCartTapped: _openCart,
            ),
          ),
        ],
      ),
      bottomNavigationBar: hasBottomBar
          ? _buildBottomBar(displayProduct)
          : null,
    );
  }

  void _openCart() {
    context.pushSlideRight(const CartScreen());
  }

  Widget _buildProductDetails(ProductWithVariants activeProduct) {
    final mv = context.meatvo;
    final product = activeProduct.product;
    final isInWishlist = ref.watch(wishlistProvider).contains(widget.productId);
    final description = (product.description ?? '').trim();
    final resolvedVariant =
        _selectedVariant ?? _defaultVariant(activeProduct);
    final currentPrice = _priceFor(activeProduct, variant: resolvedVariant);
    final originalPrice = _originalPriceFor(activeProduct, variant: resolvedVariant);
    final showOriginalPrice = product.hasDiscount && originalPrice > currentPrice;
    final categoryName = (product.categoryName ?? '').trim();
    final bottomInset = MeatvoLayout.productDetailScrollBottomInset(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: ProductDetailScreen._imageHeight,
            width: double.infinity,
            child: _buildProductImage(activeProduct, isInWishlist: isInWishlist),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: mv.surfaceCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: RefreshIndicator(
                onRefresh: () => _loadProduct(forceRefresh: true),
                color: mv.brandAccent,
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                  children: [
                    StoreClosedBanner(
                      status: ref.watch(storeSettingsSyncProvider),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      product.name,
                      style: AppTextStyles.h2.copyWith(color: mv.textPrimary),
                    ),
                    if (categoryName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: mv.brandAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: mv.brandAccent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Text(
                          '₹${currentPrice.toStringAsFixed(0)}',
                          style: AppTextStyles.h1.copyWith(color: mv.brandAccent),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/$_displayUnit',
                            style: AppTextStyles.caption.copyWith(
                              color: mv.textSecondary,
                            ),
                          ),
                        ),
                        if (showOriginalPrice)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'MRP ₹${originalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: mv.textSecondary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Fresh • Hygienically Packed • No Additives',
                      style: AppTextStyles.caption.copyWith(
                        color: mv.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppThemeColors.divider),
                    const SizedBox(height: 16),
                    if (activeProduct.variants.isNotEmpty)
                      _buildVariantSelector(activeProduct),
                    if (activeProduct.variants.isNotEmpty) const SizedBox(height: 16),
                    _buildRatingRow(),
                    const SizedBox(height: 16),
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        maxLines: _isDescriptionExpanded ? null : 3,
                        overflow: _isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: mv.textSecondary,
                        ),
                      ),
                      if (description.length > 120)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isDescriptionExpanded = !_isDescriptionExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _isDescriptionExpanded ? 'Read less' : 'Read more',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: mv.brandAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    _buildRelatedSection(),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductImage(
    ProductWithVariants activeProduct, {
    required bool isInWishlist,
  }) {
    final mv = context.meatvo;
    final product = activeProduct.product;
    final imageUrl = product.primaryImageUrl;
    final heroTag = getProductHeroTag(product.id);
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (product.allImages.length > 1) {
              _showImageGallery(product.allImages, 0);
            } else {
              _showImageZoom(imageUrl);
            }
          },
          child: Hero(
            tag: heroTag,
            child: CachedNetworkImage(
              imageUrl: imageUrl ?? '',
              width: double.infinity,
              height: ProductDetailScreen._imageHeight,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppThemeColors.surface2,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      mv.brandAccent,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppThemeColors.surface2,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/icons/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported,
                    size: 40,
                    color: AppThemeColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: topPadding,
          left: 16,
          child: _overlayCircleButton(
            icon: Icons.arrow_back,
            iconColor: mv.textPrimary,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          top: topPadding,
          right: 16,
          child: _overlayCircleButton(
            icon: isInWishlist ? Icons.favorite : Icons.favorite_border,
            iconColor: isInWishlist ? mv.brandAccent : mv.textPrimary,
            onTap: _toggleWishlist,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow() {
    final hasRating = _reviewCount > 0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.star_rounded,
                size: 16,
                color: hasRating && index < _averageRating.round()
                    ? AppThemeColors.accentGold
                    : AppThemeColors.accentGold.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        Text(
          hasRating ? '$_averageRating ($_reviewCount reviews)' : 'No reviews yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.textSecondary,
              ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: (_isInStock ? AppThemeColors.success : AppThemeColors.warning)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _isInStock ? 'In Stock' : 'Out of Stock',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _isInStock
                      ? AppThemeColors.success
                      : AppThemeColors.warning,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSelector(ProductWithVariants activeProduct) {
    final mv = context.meatvo;
    final variants = activeProduct.availableVariants.isNotEmpty
        ? activeProduct.availableVariants
        : activeProduct.variants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ProductUnitHelper.isPieceUnit(activeProduct.product.unit)
              ? 'Select quantity'
              : 'Select weight',
          style: AppTextStyles.button.copyWith(
            fontSize: 15,
            color: mv.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variants.map((variant) {
            final isSelected = _selectedVariant?.id == variant.id;
            final isAvailable = variant.isAvailable && variant.stock > 0;
            return FilterChip(
              label: Text(
                variant.weight,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? mv.surfaceCard : mv.brandAccent,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: isAvailable
                  ? (_) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedVariant = variant;
                      });
                    }
                  : null,
              selectedColor: mv.brandAccent,
              backgroundColor: mv.surfaceCard,
              side: BorderSide(color: mv.brandAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final mv = context.meatvo;
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: onTap == null
                  ? AppThemeColors.textMuted.withValues(alpha: 0.3)
                  : mv.brandAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: mv.surfaceCard,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedSection() {
    if (_isLoadingRelated) {
      return const ShimmerLoader.productCard(count: 3);
    }

    if (_relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related products',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppThemeColors.textPrimary,
              ),
        ),
        SizedBox(height: AppSpacing.sm),
        // Related products now use `MeatvoProductCard` (production-safe)
        // instead of the legacy `ProductCard`. The legacy card was a
        // documented source of:
        //   • "BoxConstraints forces an infinite width" when dropped
        //     into the horizontal list without a SizedBox wrapper
        //   • IconButton-driven `_RenderInputPadding` crashes on tight
        //     wishlist/add rows
        //   • `related.product.discount!` style null bangs
        // MeatvoProductCard already enforces a fallback width, no
        // IconButton, deterministic CTA pill, and full null-safety.
        SizedBox(
          height: ProductCardAdapter.carouselHeight(
            MediaQuery.sizeOf(context).width,
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProducts.length,
            separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final related = _relatedProducts[index];
              // Local non-null capture pattern — drops every `relatedCartItem.itemId!`
              // bang downstream. The closures are scheduled asynchronously,
              // so an instance-field-level `!` could hit a stale rebuild.
              final relatedCartItem =
                  _cart.findItemByProductId(related.product.id);
              final localItemId = relatedCartItem?.itemId;
              final localCartQty = relatedCartItem?.quantity.round() ?? 0;
              final storeStatus = ref.watch(storeSettingsSyncProvider);
              final cardWidth = ProductCardAdapter.carouselWidth(
                MediaQuery.sizeOf(context).width,
              );

              Future<void> guardedRelatedChange(int next) async {
                await OrderingGate.guardQuantityChange(
                  context,
                  ref,
                  currentQuantity: localCartQty,
                  nextQuantity: next,
                  action: () async {
                    final preferredVariant =
                        related.availableVariants.isNotEmpty
                            ? related.availableVariants.first
                            : (related.variants.isNotEmpty
                                ? related.variants.first
                                : null);
                    if (localCartQty == 0 && next > 0) {
                      await _cartService.addToCart(
                        related.product.id,
                        1,
                        unit: preferredVariant?.weight ?? related.product.unit,
                        variantId: preferredVariant?.id,
                      );
                    } else if (localItemId != null &&
                        localItemId.isNotEmpty &&
                        next > 0) {
                      await _cartService.updateCartItem(localItemId, next);
                    } else if (localItemId != null &&
                        localItemId.isNotEmpty &&
                        next <= 0) {
                      await _cartService.removeFromCart(localItemId);
                    }
                    if (mounted) {
                      final refreshedCart =
                          await _cartService.getCart().catchError((_) => _cart);
                      setState(() => _cart = refreshedCart);
                    }
                  },
                );
              }

              final bindings = ProductCardBindings.forProduct(
                storeStatus: storeStatus,
                product: related,
                cart: _cart,
                onQuantityChange: (p, next) => guardedRelatedChange(next),
              );

              return SizedBox(
                width: cardWidth,
                child: MeatvoProductCard(
                  product: related.product.copyWith(
                    unit: ProductCardAdapter.displayUnit(related),
                  ),
                  displayPrice: ProductCardAdapter.displayPrice(related),
                  displayUnit: ProductCardAdapter.displayUnit(related),
                  originalPrice: ProductCardAdapter.originalPrice(related),
                  discountPercent: related.product.discount,
                  quantity: localCartQty,
                  inStock: bindings.inStock,
                  orderingPaused: bindings.orderingPaused,
                  layout: MeatvoProductCardLayout.carousel,
                  onTap: () {
                    Navigator.of(context).push(
                      AppTransitions.scale(
                        ProductDetailScreen(
                          productId: related.product.id,
                          initialProduct: related,
                        ),
                      ),
                    );
                  },
                  onAdd: bindings.onAdd,
                  onIncrement: bindings.onIncrement,
                  onDecrement: bindings.onDecrement,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _priceFor(
    ProductWithVariants activeProduct, {
    ProductVariantModel? variant,
  }) {
    final selected = variant ?? _selectedVariant;
    if (selected != null) {
      final variantPrice = selected.price;
      if (variantPrice > 0) return variantPrice;
      return activeProduct.product.finalPrice * selected.weightValue;
    }
    return activeProduct.product.finalPrice;
  }

  double _originalPriceFor(
    ProductWithVariants activeProduct, {
    ProductVariantModel? variant,
  }) {
    final selected = variant ?? _selectedVariant;
    if (selected != null) {
      return activeProduct.product.price * selected.weightValue;
    }
    return activeProduct.product.price;
  }

  Widget _buildBottomBar(ProductWithVariants activeProduct) {
    final mv = context.meatvo;
    final hasExistingCartItem = _currentCartItem != null;
    final totalPrice = _priceFor(activeProduct) * _quantity;
    final storeStatus = ref.watch(storeSettingsSyncProvider);
    final storeClosedButInStock = _isInStock && !storeStatus.isAcceptingOrders;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: mv.surfaceCard,
          boxShadow: [
            BoxShadow(
              color: mv.border,
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mv.brandAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            if (hasExistingCartItem)
              _buildCartQuantityStepper()
            else
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: !_isInStock
                      ? null
                      : () async {
                          if (storeClosedButInStock) {
                            await StoreClosedSheet.show(context, storeStatus);
                            return;
                          }
                          _saveCart();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mv.brandAccent,
                    disabledBackgroundColor:
                        mv.brandAccent.withValues(alpha: 0.4),
                    foregroundColor: mv.surfaceCard,
                    elevation: 0,
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    storeClosedButInStock ? 'Not accepting orders' : 'Add to Cart',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 15,
                      color: mv.surfaceCard,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartQuantityStepper() {
    final mv = context.meatvo;
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            icon: Icons.remove,
            onTap: _quantity > 1
                ? () {
                    setState(() {
                      _quantity--;
                    });
                    _saveCart();
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_quantity',
              style: AppTextStyles.h3.copyWith(color: mv.textPrimary),
            ),
          ),
          _stepperButton(
            icon: Icons.add,
            onTap: () async {
                    final storeStatus = ref.read(storeSettingsSyncProvider);
                    if (!storeStatus.isAcceptingOrders) {
                      await StoreClosedSheet.show(context, storeStatus);
                      return;
                    }
                    setState(() {
                      _quantity++;
                    });
                    _saveCart();
                  },
          ),
        ],
      ),
    );
  }

  Widget _overlayCircleButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final mv = context.meatvo;
    return Material(
      color: mv.surfaceCard,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: mv.surfaceCard,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: mv.border,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showImageZoom(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;
    final mv = context.meatvo;

    showDialog(
      context: context,
      barrierColor: mv.textPrimary.withValues(alpha: 0.87),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedImageWidget(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mv.textSecondary.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: mv.surfaceCard,
                    size: 24,
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    final mv = context.meatvo;

    showDialog(
      context: context,
      barrierColor: mv.textPrimary.withValues(alpha: 0.87),
      builder: (context) => _ImageGalleryDialog(
        images: images,
        initialIndex: initialIndex,
      ),
    );
  }
}

/// Image Gallery Dialog - Shows multiple product images with swipe support
class _ImageGalleryDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageGalleryDialog({
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedImageWidget(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: mv.textSecondary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: mv.surfaceCard,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mv.textSecondary.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: mv.surfaceCard,
                  size: 24,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: _currentIndex == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentIndex == index
                            ? mv.surfaceCard
                            : mv.surfaceCard.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
