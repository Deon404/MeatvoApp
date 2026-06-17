import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cart_model.dart';
import '../../models/product_variant_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/api_service.dart' show RealtimeChannel;
import '../../services/cart_service.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../utils/app_transitions.dart';
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

/// Product Detail Screen - Full product information with variants and add to cart
class ProductDetailScreen extends ConsumerStatefulWidget {
  static const _brandRed = Color(0xFFC8102E);
  static const _textDark = Color(0xFF1A1A1A);
  static const _greyCaption = Color(0xFF6B7280);
  static const _imageHeight = 260.0;
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
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

  bool _isAddingToCart = false;
  bool _isLoadingRelated = false;
  bool _isDescriptionExpanded = false;
  int _quantity = 1;
  double _averageRating = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToProductUpdates();

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
    return product.product.isAvailable && (product.product.stock ?? 1) > 0;
  }

  String get _displayUnit => _displayUnitFor(_product?.product.unit);

  String _displayUnitFor(String? rawUnit) {
    final unit = (rawUnit ?? '').trim().toLowerCase();
    if (unit.contains('piece') || unit.contains('pc')) return 'piece';
    if (unit.contains('kg') || unit.contains('gm') || unit.contains('g')) {
      return 'kg';
    }
    return unit.isEmpty ? 'piece' : unit;
  }

  Future<void> _saveCart() async {
    // Local non-null capture — the bang `_product!.product` below would
    // crash mid-await if a realtime product-update nulled `_product`.
    final localProduct = _product;
    if (localProduct == null || !_isInStock || _isAddingToCart) return;

    final storeStatus = ref.read(storeSettingsSyncProvider);
    final cartItem = _currentCartItem;
    final previousQty = cartItem?.quantity.round() ?? 0;
    if (!storeStatus.isOpen && _quantity > previousQty) {
      await StoreClosedSheet.show(context, storeStatus);
      if (mounted && cartItem != null) {
        setState(() => _quantity = previousQty);
      }
      return;
    }

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final product = localProduct.product;
      final cartItem = _currentCartItem;
      final selectedVariantId = _selectedVariant?.id;
      final selectedUnit = _selectedVariant?.weight ?? product.unit;

      // Capture cartItem.itemId into a local so the `cartItem.itemId!`
      // bangs disappear — instance fields cannot be smart-cast across
      // the awaits in this block.
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cartItem == null ? 'Added to cart successfully!' : 'Cart updated successfully!',
          ),
          backgroundColor: AppThemeColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update cart: $e'),
          backgroundColor: AppThemeColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final loadedProduct = productAsync.asData?.value;
    final showFallbackAppBar = loadedProduct == null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppThemeColors.background,
      appBar: showFallbackAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: productAsync.when(
        loading: () => const ShimmerLoader.productDetail(),
        error: (err, _) => ErrorStateWidget(
          title: 'Failed to load product',
          message: err.toString().replaceFirst('Exception: ', ''),
          buttonLabel: 'Retry',
          icon: Icons.error_outline,
          onRetry: () => ref.refresh(productDetailProvider(widget.productId)),
        ),
        data: (product) {
          if (product == null) {
            return const EmptyStateWidget(
              title: 'Product not found',
              message: 'Try exploring other fresh picks from the catalogue.',
            );
          }
          return _buildProductDetails(product);
        },
      ),
      bottomNavigationBar: loadedProduct != null
          ? _buildBottomBar(loadedProduct)
          : null,
    );
  }

  Widget _buildProductDetails(ProductWithVariants activeProduct) {
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: RefreshIndicator(
                onRefresh: () => _loadProduct(forceRefresh: true),
                color: ProductDetailScreen._brandRed,
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
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ProductDetailScreen._textDark,
                      ),
                    ),
                    if (categoryName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ProductDetailScreen._brandRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ProductDetailScreen._brandRed,
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
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: ProductDetailScreen._brandRed,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/$_displayUnit',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: ProductDetailScreen._greyCaption,
                            ),
                          ),
                        ),
                        if (showOriginalPrice)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'MRP ₹${originalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: ProductDetailScreen._greyCaption,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFreshnessStrip(),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppThemeColors.divider),
                    const SizedBox(height: 16),
                    if (activeProduct.variants.isNotEmpty)
                      _buildVariantSelector(activeProduct),
                    if (activeProduct.variants.isNotEmpty) const SizedBox(height: 16),
                    _buildRatingRow(),
                    const SizedBox(height: 16),
                    Text(
                      description.isEmpty
                          ? 'Freshly packed premium cuts perfect for your next meal.'
                          : description,
                      maxLines: _isDescriptionExpanded || description.isEmpty ? null : 3,
                      overflow: _isDescriptionExpanded || description.isEmpty
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        height: 1.5,
                        color: ProductDetailScreen._greyCaption,
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
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ProductDetailScreen._brandRed,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildFreshnessStrip() {
    return Row(
      children: [
        Expanded(
          child: _freshnessItem(Icons.access_time, 'Slaughtered Today'),
        ),
        Expanded(
          child: _freshnessItem(Icons.ac_unit, 'Air Chilled'),
        ),
        Expanded(
          child: _freshnessItem(Icons.shield_outlined, 'No Additives'),
        ),
      ],
    );
  }

  Widget _freshnessItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: ProductDetailScreen._brandRed,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: ProductDetailScreen._greyCaption,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(
    ProductWithVariants activeProduct, {
    required bool isInWishlist,
  }) {
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
                child: const SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ProductDetailScreen._brandRed,
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
            iconColor: ProductDetailScreen._textDark,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          top: topPadding,
          right: 16,
          child: _overlayCircleButton(
            icon: isInWishlist ? Icons.favorite : Icons.favorite_border,
            iconColor: isInWishlist
                ? ProductDetailScreen._brandRed
                : ProductDetailScreen._textDark,
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: (_isInStock ? AppThemeColors.success : AppThemeColors.warning)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
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
    final variants = activeProduct.availableVariants.isNotEmpty
        ? activeProduct.availableVariants
        : activeProduct.variants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select weight',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ProductDetailScreen._textDark,
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
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : ProductDetailScreen._brandRed,
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
              selectedColor: ProductDetailScreen._brandRed,
              backgroundColor: Colors.white,
              side: const BorderSide(color: ProductDetailScreen._brandRed),
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
                  : ProductDetailScreen._brandRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Colors.white,
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
        const SizedBox(height: AppSpacing.sm),
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
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
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
                    Navigator.of(context).pushReplacement(
                      AppTransitions.scale(
                        ProductDetailScreen(productId: related.product.id),
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
    final hasExistingCartItem = _currentCartItem != null;
    final totalPrice = _priceFor(activeProduct) * _quantity;
    final storeStatus = ref.watch(storeSettingsSyncProvider);
    final storeClosedButInStock = _isInStock && !storeStatus.isOpen;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ProductDetailScreen._brandRed,
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
                  onPressed: !_isInStock || _isAddingToCart
                      ? null
                      : () async {
                          if (storeClosedButInStock) {
                            await StoreClosedSheet.show(context, storeStatus);
                            return;
                          }
                          await _saveCart();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProductDetailScreen._brandRed,
                    disabledBackgroundColor:
                        ProductDetailScreen._brandRed.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAddingToCart
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          storeClosedButInStock ? 'Store closed' : 'Add to Cart',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            icon: Icons.remove,
            onTap: _quantity > 1 && !_isAddingToCart
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
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ProductDetailScreen._textDark,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add,
            onTap: !_isAddingToCart
                ? () async {
                    final storeStatus = ref.read(storeSettingsSyncProvider);
                    if (!storeStatus.isOpen) {
                      await StoreClosedSheet.show(context, storeStatus);
                      return;
                    }
                    setState(() {
                      _quantity++;
                    });
                    _saveCart();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _overlayCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = ProductDetailScreen._textDark,
  }) {
    return Material(
      color: Colors.white,
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
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
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
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
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
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
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
                            ? AppThemeColors.white
                            : AppThemeColors.white.withValues(alpha: 0.5),
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

