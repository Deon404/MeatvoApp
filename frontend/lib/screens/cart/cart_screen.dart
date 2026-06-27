import 'package:flutter/material.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../domain/order_pricing.dart';
import '../../models/cart_model.dart';
import '../../services/cart_service.dart';
import '../../services/coupon_service.dart';
import '../../services/store_status_service.dart';
import '../../theme/app_theme.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../widgets/cart/cart_bill_summary.dart';
import '../../widgets/cart/cart_coupon_section.dart';
import '../../widgets/cart/cart_floating_checkout.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/shimmer_loader.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key, 
    this.inTabShell = false,
    this.onNavigateToHome,
  });

  final bool inTabShell;
  final VoidCallback? onNavigateToHome;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final CouponService _couponService = CouponService();
  final StoreStatusService _storeStatusService = StoreStatusService();

  CartModel? _cart;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isCheckingOut = false;
  final Set<String> _updatingItems = {};
  String? _errorMessage;
  String? _appliedCouponCode;
  double _couponDiscount = 0;
  String? _couponErrorMessage;
  double _deliveryFeeAmount = OrderPricingCalculator.defaultDeliveryChargeAmount;

  @override
  void initState() {
    super.initState();
    CartService.cartNotifier.addListener(_onGlobalCartChanged);
    _loadCartData();
    _loadStoreSettings();
  }

  Future<void> _loadStoreSettings() async {
    try {
      final status = await _storeStatusService.fetchStatus();
      if (!mounted) return;
      setState(() => _deliveryFeeAmount = status.deliveryFee);
    } catch (_) {
      // Keep default delivery fee when store settings are unavailable.
    }
  }

  @override
  void dispose() {
    CartService.cartNotifier.removeListener(_onGlobalCartChanged);
    super.dispose();
  }

  void _onGlobalCartChanged() {
    if (!mounted) return;
    setState(() => _cart = CartService.cartNotifier.value);
  }

  Future<void> _loadCartData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final cart = await _cartService.getCart();

      if (!mounted) return;

      setState(() {
        _cart = cart;
        _isLoading = false;
        _isUpdating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your cart. Please try again.';
        _isLoading = false;
        _isUpdating = false;
      });
    }
  }

  String? _cartLineKey(CartItem item) {
    if (item.productId.isNotEmpty) return item.productId;
    final id = item.itemId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> _updateQuantity(
    CartItem item,
    double newQuantity,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final lineKey = _cartLineKey(item);
    if (lineKey == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cart item id missing'),
          backgroundColor: context.meatvo.brandPrimaryDark,
        ),
      );
      return;
    }

    // Optimistic UI: Update immediately in local state
    final previousCart = _cart;
    setState(() {
      _updatingItems.add(lineKey);
      if (_cart != null) {
        final updatedItems = _cart!.items.map((i) {
          if (_cartLineKey(i) == lineKey) {
            return i.copyWith(quantity: newQuantity);
          }
          return i;
        }).where((i) => i.quantity > 0).toList();
        _cart = CartModel(items: updatedItems);
      }
    });

    try {
      if (newQuantity <= 0) {
        await _cartService.removeFromCart(lineKey);
      } else {
        await _cartService.updateCartItem(
          lineKey,
          newQuantity.round(),
        );
      }

      await _syncCartData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cart = previousCart);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cart Update Failed'),
          content: const Text(
            'Could not update your cart. Would you like to try again?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadCartData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingItems.remove(lineKey));
      }
    }
  }

  // Background sync without showing global loading
  Future<void> _syncCartData() async {
    try {
      final cart = await _cartService.getCart();
      if (mounted) {
        setState(() => _cart = cart);
      }
    } catch (_) {
      // Silent failure - we already have the optimistic state
    }
  }

  Future<void> _removeItem(CartItem item) async {
    await _updateQuantity(item, 0);
  }

  int get _itemCount => _cart?.totalQuantity.round() ?? 0;

  double get _subtotal => _cart?.subtotal ?? 0;

  double get _productDiscount => _cart?.totalDiscount ?? 0;

  OrderPricingBreakdown get _pricing => OrderPricingCalculator.calculate(
        subtotal: _subtotal,
        discount: _productDiscount + _couponDiscount,
        deliveryChargeAmount: _deliveryFeeAmount,
      );

  double get _deliveryFee => _pricing.deliveryCharge;

  double get _total => _pricing.grandTotal;

  Future<bool> _applyCoupon(String code) async {
    setState(() => _couponErrorMessage = null);

    final result = await _couponService.validateCoupon(code, _subtotal);

    if (!mounted) return false;

    if (!result.isValid) {
      setState(() => _couponErrorMessage = result.errorMessage ?? 'Invalid coupon');
      return false;
    }

    setState(() {
      _appliedCouponCode = code.trim().toUpperCase();
      _couponDiscount = result.discountAmount;
      _couponErrorMessage = null;
    });
    return true;
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0;
      _couponErrorMessage = null;
    });
  }


  Future<void> _handlePlaceOrder() async {
    if (_isCheckingOut) return;

    final messenger = ScaffoldMessenger.of(context);
    final currentCart = _cart;
    if (currentCart == null || currentCart.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cart is empty'),
          backgroundColor: context.meatvo.brandPrimaryDark,
        ),
      );
      return;
    }

    setState(() => _isCheckingOut = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            cart: currentCart,
            selectedAddress: null,
            couponCode: _appliedCouponCode,
            couponDiscount: _couponDiscount,
          ),
        ),
      );

      if (mounted) {
        await _loadCartData();
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    // Local copy enables Dart smart-cast → no `!` operator below.
    final cart = _cart;
    final hasItems = cart != null && cart.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mv.surfaceWarm,
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : !hasItems
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildCartContent()),
                      ],
                    ),
    );
  }

  Widget _buildCartContent() {
    final mv = context.meatvo;
    // _buildCartContent is only reached when hasItems == true (guarded in
    // build()), but capturing once removes the lingering `_cart!` bang.
    final cart = _cart;
    final items = cart?.items ?? const [];
    return RefreshIndicator(
      onRefresh: _loadCartData,
      color: mv.brandPrimary,
      edgeOffset: 8,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          mv.spacing.md,
          mv.spacing.sm,
          mv.spacing.md,
          mv.spacing.lg +
              (widget.inTabShell
                  ? MeatvoLayout.tabScrollBottomPadding(context)
                  : MeatvoLayout.systemBottomInset(context)),
        ),
        children: [
          ...items.map(_buildDismissibleItem),
          SizedBox(height: mv.spacing.md),
          CartCouponSection(
            appliedCode: _appliedCouponCode,
            appliedDiscount: _couponDiscount,
            errorMessage: _couponErrorMessage,
            onApply: _applyCoupon,
            onRemove: _removeCoupon,
          ),
          SizedBox(height: mv.spacing.md),
          CartBillSummary(
            itemTotal: _subtotal,
            productDiscount: _productDiscount,
            couponDiscount: _couponDiscount,
            deliveryCharge: _deliveryFee,
            grandTotal: _total,
            itemCount: _itemCount,
            isFreeDelivery: _pricing.isFreeDelivery,
          ),
          SizedBox(height: mv.spacing.md),
          CartFloatingCheckout(
            total: _total,
            isLoading: _isUpdating || _isCheckingOut,
            onCheckout: _handlePlaceOrder,
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleItem(CartItem item) {
    final mv = context.meatvo;
    return Dismissible(
      key: ValueKey(
        item.itemId ?? '${item.productId}_${item.variantId ?? 'default'}',
      ),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.symmetric(vertical: mv.spacing.xxs + 2),
        decoration: BoxDecoration(
          color: mv.brandPrimary,
          borderRadius: BorderRadius.circular(mv.radii.lg),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: mv.spacing.lg),
        child: Icon(Icons.delete_rounded, color: MeatvoColors.white, size: 24),
      ),
      onDismissed: (_) => _removeItem(item),
      child: CartItemTile(
        item: item,
        isBusy: _updatingItems.contains(_cartLineKey(item)),
        onDecrement: _updatingItems.contains(_cartLineKey(item))
            ? null
            : () => _updateQuantity(item, item.quantity - 1),
        onIncrement: _updatingItems.contains(_cartLineKey(item))
            ? null
            : () => _updateQuantity(item, item.quantity + 1),
      ),
    );
  }

  Widget _buildHeader() {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: mv.surfaceWarm,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mv.spacing.md,
            mv.spacing.sm,
            mv.spacing.md,
            mv.spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Cart',
                style: textTheme.headlineSmall?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: mv.spacing.xxs),
              Text(
                '($_itemCount ${_itemCount == 1 ? 'item' : 'items'})',
                style: textTheme.bodyMedium?.copyWith(
                  color: mv.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.cart(
      buttonLabel: 'Start Shopping',
      onAction: () {
        if (widget.inTabShell && widget.onNavigateToHome != null) {
          // Switch to home tab when cart is embedded in tab shell
          widget.onNavigateToHome!();
        } else {
          // Pop navigation stack when cart is a standalone screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  Widget _buildErrorState() {
    return ErrorStateWidget(
      title: 'Unable to load cart',
      message: _errorMessage ?? 'Could not load your cart. Please try again.',
      onRetry: _loadCartData,
    );
  }

  Widget _buildLoadingState() {
    final mv = context.meatvo;
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(mv.spacing.md),
            children: const [
              ShimmerLoader.listTile(),
              SizedBox(height: AppSpacing.sm),
              ShimmerLoader.listTile(),
            ],
          ),
        ),
      ],
    );
  }
}


