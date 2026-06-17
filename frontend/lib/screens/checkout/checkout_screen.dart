import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/address_model.dart';
import '../../models/cart_model.dart';
import '../../services/address_service.dart';
import '../../services/cart_service.dart';
import '../../services/delivery_service.dart';
import '../../services/store_status_service.dart';
import '../../services/order_service.dart';
import '../../services/checkout_preferences.dart';
import '../../services/payment_service.dart';
import '../../domain/order_pricing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/shimmer_loader.dart';
import '../../widgets/checkout/checkout_delivery_sections.dart';
import '../../widgets/checkout/checkout_payment_methods.dart';
import '../../widgets/checkout/checkout_place_order_bar.dart';
import '../../widgets/checkout/checkout_success_overlay.dart';
import '../../widgets/location/delivery_location_sheet.dart';
import '../../widgets/store/store_closed_sheet.dart';
import '../orders/order_confirmation_screen.dart';
import '../payment/payment_processing_screen.dart';

/// Premium checkout — address, express delivery, payment, place order.
class CheckoutScreen extends StatefulWidget {
  final CartModel cart;
  final AddressModel? selectedAddress;
  final String? couponCode;
  final double couponDiscount;

  const CheckoutScreen({
    super.key,
    required this.cart,
    this.selectedAddress,
    this.couponCode,
    this.couponDiscount = 0,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AddressService _addressService = AddressService();
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();
  final DeliveryService _deliveryService = DeliveryService();
  final StoreStatusService _storeStatusService = StoreStatusService();
  final PaymentService _paymentService = PaymentService();

  AddressModel? _selectedAddress;
  CartModel? _cart;
  List<AddressModel> _addresses = [];
  bool _isStoreOpen = true;
  StoreStatus? _storeStatus;
  bool _storeClosedSheetShown = false;
  double _deliveryFeeAmount = OrderPricingCalculator.defaultDeliveryChargeAmount;
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  bool _showSuccessOverlay = false;
  String? _errorMessage;

  CheckoutPaymentOption _paymentOption = CheckoutPaymentOption.cod;

  String get _paymentMethod => _paymentOption.backendValue;

  bool get _isOnlinePayment => _paymentMethod == 'ONLINE';

  CartModel get _activeCart => _cart ?? widget.cart;

  OrderPricingBreakdown get _pricing => OrderPricingCalculator.calculate(
        subtotal: _activeCart.subtotal,
        discount: _activeCart.totalDiscount + widget.couponDiscount,
        deliveryChargeAmount: _deliveryFeeAmount,
      );

  double get _subtotal => _pricing.subtotal;
  double get _discount => _pricing.discount;
  double get _calculatedDeliveryCharge => _pricing.deliveryCharge;
  double get _total => _pricing.grandTotal;

  int get _itemCount => _activeCart.items.length;

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _selectedAddress = widget.selectedAddress;
    _loadAddresses();
    _loadStoreStatus(showClosedSheet: true);
    _syncCartFromServer();
    _loadSavedPaymentOption();
  }

  Future<void> _loadStoreStatus({bool showClosedSheet = false}) async {
    try {
      final status = await _storeStatusService.fetchStatus();
      if (!mounted) return;
      setState(() {
        _storeStatus = status;
        _isStoreOpen = status.isOpen;
        _deliveryFeeAmount = status.deliveryFee;
      });
      if (showClosedSheet && !status.isOpen) {
        await _showStoreClosedSheet();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStoreOpen = true);
    }
  }

  Future<void> _showStoreClosedSheet({bool force = false}) async {
    if (!mounted || _storeStatus == null || _storeStatus!.isOpen) return;
    if (!force && _storeClosedSheetShown) return;
    _storeClosedSheetShown = true;
    await StoreClosedSheet.show(context, _storeStatus!);
  }

  Future<void> _loadSavedPaymentOption() async {
    final saved = await CheckoutPreferences.loadPaymentOption();
    if (mounted) {
      setState(() => _paymentOption = saved);
    }
  }

  Future<void> _savePaymentOption(CheckoutPaymentOption option) async {
    await CheckoutPreferences.savePaymentOption(option);
  }

  Future<void> _syncCartFromServer() async {
    try {
      final cart = await _cartService.getCart();
      if (mounted) setState(() => _cart = cart);
    } catch (_) {
      // Keep passed-in cart as fallback display.
    }
  }

  Future<void> _loadAddresses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final addresses = await _addressService.getUserAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          if (_selectedAddress == null && addresses.isNotEmpty) {
            _selectedAddress = addresses.firstWhere(
              (addr) => addr.isDefault,
              orElse: () => addresses.first,
            );
          }
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to load your saved addresses right now. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppThemeColors.error : AppThemeColors.success,
      ),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.contains('coordinates are missing')) {
      return 'Please pin your delivery location on the map before placing the order.';
    }
    if (raw.toLowerCase().contains('stock')) {
      return 'Some items are out of stock. Please update your cart.';
    }
    if (raw.toLowerCase().contains('cart is empty')) {
      return 'Your cart is empty. Add items before checkout.';
    }
    if (raw.toLowerCase().contains('store is closed')) {
      return _storeStatus?.displayClosedMessage ??
          'Store is closed — orders resume when we open.';
    }
    if (raw.toLowerCase().contains('payment service unavailable') ||
        raw.toLowerCase().contains('failed to initiate payment')) {
      return 'Order saved. Online payment is temporarily unavailable — open My Orders to retry or choose Cash on Delivery next time.';
    }
    return raw;
  }

  Future<void> _placeOrder() async {
    if (!_isStoreOpen) {
      await _showStoreClosedSheet(force: true);
      return;
    }

    if (_selectedAddress == null) {
      _showMessage('Please select a delivery address');
      return;
    }

    if (_selectedAddress!.latitude == null ||
        _selectedAddress!.longitude == null) {
      _showMessage(
        'Please pin your delivery location on the map before placing the order.',
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      CartModel cart;
      try {
        cart = await _cartService.getCart();
      } catch (_) {
        if (!mounted) return;
        setState(() => _isPlacingOrder = false);
        _showMessage('Could not sync your cart. Please try again.');
        return;
      }

      if (cart.isEmpty) {
        if (!mounted) return;
        setState(() => _isPlacingOrder = false);
        _showMessage('Your cart is empty. Add items before checkout.');
        return;
      }

      if (context.mounted) setState(() => _cart = cart);

      final validation = await _deliveryService.validateDeliveryAddress(
        latitude: _selectedAddress!.latitude!,
        longitude: _selectedAddress!.longitude!,
      );
      if (!mounted) return;

      if (!validation.isValid) {
        setState(() => _isPlacingOrder = false);
        _showMessage(validation.message);
        return;
      }

      final deliveryAddressJson = {
        'id': _selectedAddress!.id,
        'label': _selectedAddress!.label.name,
        'address_line1': _selectedAddress!.addressLine1,
        'address_line2': _selectedAddress!.addressLine2,
        'landmark': _selectedAddress!.landmark,
        'city': _selectedAddress!.city,
        'state': _selectedAddress!.state,
        'pincode': _selectedAddress!.pincode,
        'latitude': _selectedAddress!.latitude,
        'longitude': _selectedAddress!.longitude,
      };

      final order = await _orderService.createOrder(
        cart: cart,
        deliveryAddress: deliveryAddressJson,
        paymentMethod: _paymentMethod,
        couponCode: widget.couponCode,
      );

      if (!mounted) return;

      final serverPayment = order.paymentMethod.toUpperCase();
      if (_isOnlinePayment && serverPayment != 'ONLINE') {
        setState(() => _isPlacingOrder = false);
        _showMessage(
          'Payment mode mismatch. Order was saved as Cash on Delivery.',
          isError: false,
        );
        return;
      }
      if (!_isOnlinePayment && serverPayment == 'ONLINE') {
        setState(() => _isPlacingOrder = false);
        _showMessage(
          'Payment mode mismatch. Please retry from My Orders.',
        );
        return;
      }

      final isOnlineOrder =
          _isOnlinePayment && serverPayment == 'ONLINE';

      if (isOnlineOrder) {
        setState(() => _isPlacingOrder = false);

        try {
          await _cartService.getCart();
        } catch (_) {}

        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentProcessingScreen(
              order: order,
              deliveryAddress: deliveryAddressJson,
              paymentService: _paymentService,
              amount: order.finalAmount > 0 ? order.finalAmount : _total,
            ),
          ),
        );
        return;
      }

      setState(() {
        _isPlacingOrder = false;
        _showSuccessOverlay = true;
      });

      // Backend clears cart on order create — sync local badge/state.
      try {
        await _cartService.getCart();
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            order: order,
            deliveryAddress: deliveryAddressJson,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _openAddAddress() async => _selectAddress();

  Future<void> _selectAddress() async {
    final result = await DeliveryLocationSheet.showPicker(
      context,
      selectedAddressId: _selectedAddress?.id,
    );

    if (result == null || !mounted) return;

    await _loadAddresses();
    if (!mounted) return;

    setState(() {
      _selectedAddress = _addresses.firstWhere(
        (a) => a.id == result.id,
        orElse: () => result,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final canPlaceOrder = _isStoreOpen &&
        _selectedAddress != null &&
        _selectedAddress!.latitude != null &&
        _selectedAddress!.longitude != null;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: mv.surfaceWarm,
          appBar: AppBar(
            backgroundColor: mv.surfaceWarm,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: mv.textPrimary),
              onPressed: _isPlacingOrder ? null : () => Navigator.pop(context),
            ),
            title: Text(
              'Checkout',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: mv.textPrimary,
                  ),
            ),
            centerTitle: true,
          ),
          body: _isLoading
              ? const ShimmerLoader.listTile(count: 4)
              : _errorMessage != null
                  ? ErrorStateWidget(
                      title: 'Checkout unavailable',
                      message: _errorMessage,
                      onRetry: _loadAddresses,
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        mv.spacing.md,
                        mv.spacing.xs,
                        mv.spacing.md,
                        130,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_addresses.isEmpty)
                            EmptyStateWidget(
                              title: 'No saved address',
                              message:
                                  'Add a delivery address to continue checkout.',
                              buttonLabel: 'Add address',
                              onAction: _openAddAddress,
                              fullScreen: false,
                            )
                          else ...[
                            CheckoutDeliverySection(
                              selectedAddress: _selectedAddress,
                              isEmptyAddress: _selectedAddress == null,
                              onChangeAddress: _selectAddress,
                              onAddAddress: _openAddAddress,
                              isStoreOpen: _isStoreOpen,
                              storeClosedMessage: _isStoreOpen
                                  ? null
                                  : (_storeStatus?.displayClosedMessage ??
                                      'Store is closed — orders resume when we open.'),
                            ),
                            SizedBox(height: mv.spacing.lg),
                            CheckoutPaymentMethods(
                              selected: _paymentOption,
                              onSelected: (option) {
                                setState(() => _paymentOption = option);
                                _savePaymentOption(option);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
          bottomNavigationBar: _addresses.isEmpty || _isLoading
              ? null
              : CheckoutPlaceOrderBar(
                  bill: CheckoutBillBreakdown(
                    subtotal: _subtotal,
                    discount: _discount,
                    deliveryCharge: _calculatedDeliveryCharge,
                    total: _total,
                    itemCount: _itemCount,
                  ),
                  isEnabled: canPlaceOrder,
                  isLoading: _isPlacingOrder,
                  onPlaceOrder: _placeOrder,
                ),
        ),
        if (_isPlacingOrder && !_showSuccessOverlay)
          const CheckoutLoadingOverlay(),
        if (_showSuccessOverlay)
          CheckoutSuccessOverlay(
            message: _isOnlinePayment
                ? 'Opening secure payment…'
                : 'Your fresh order is on its way.',
          ),
      ],
    );
  }
}

