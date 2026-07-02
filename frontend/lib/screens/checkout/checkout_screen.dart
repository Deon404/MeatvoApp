import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/order_model.dart';
import '../../models/address_model.dart';
import '../../models/cart_model.dart';
import '../../services/address_service.dart';
import '../../services/cart_service.dart';
import '../../services/coupon_service.dart';
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
import '../../widgets/checkout/checkout_cancellation_policy.dart';
import '../../widgets/checkout/checkout_delivery_sections.dart';
import '../../widgets/checkout/checkout_order_summary.dart';
import '../../widgets/checkout/checkout_payment_method_sheet.dart';
import '../../widgets/checkout/checkout_payment_types.dart';
import '../../widgets/checkout/checkout_place_order_bar.dart';
import '../../widgets/checkout/checkout_quick_pay_sheet.dart';
import '../../widgets/checkout/checkout_success_overlay.dart';
import '../../widgets/active_flow/active_flow_shell.dart';
import '../../widgets/location/delivery_location_sheet.dart';
import '../../widgets/store/store_closed_sheet.dart';
import '../orders/order_confirmation_screen.dart';
import '../payment/payment_processing_screen.dart';

/// Review & Pay — bill summary, policy, address, payment sheets, place order.
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
  bool _storeStatusError = false;
  double _deliveryFeeAmount = OrderPricingCalculator.defaultDeliveryChargeAmount;
  double _freeDeliveryThreshold = 500;
  bool _isLoading = true;
  bool _isPlacingOrder = false;
  bool _showSuccessOverlay = false;
  String? _errorMessage;
  String? _placeOrderError;
  String? _couponCode;
  double _couponDiscount = 0;

  CheckoutPaymentOption? _paymentOption;
  CheckoutUpiSelection _upiSelection = CheckoutUpiSelection.nativePicker;
  String? _selectedUpiPackageId;

  String get _paymentMethod =>
      (_paymentOption ?? CheckoutPaymentOption.cod).backendValue;

  bool get _isOnlinePayment => _paymentMethod == 'ONLINE';

  CashfreeCheckoutMode _resolveCashfreeCheckoutMode() {
    return switch (_upiSelection) {
      CheckoutUpiSelection.webCheckout => CashfreeCheckoutMode.webCheckout,
      CheckoutUpiSelection.installedApp => CashfreeCheckoutMode.upiApp,
      CheckoutUpiSelection.nativePicker => CashfreeCheckoutMode.upiIntentPicker,
    };
  }

  CartModel get _activeCart => _cart ?? widget.cart;

  double get _productDiscount => _activeCart.totalDiscount;

  OrderPricingBreakdown get _pricing => OrderPricingCalculator.calculate(
        subtotal: _activeCart.subtotal,
        discount: _productDiscount + _couponDiscount,
        deliveryChargeAmount: _deliveryFeeAmount,
        freeDeliveryThreshold: _freeDeliveryThreshold,
      );

  double get _subtotal => _pricing.subtotal;
  double get _calculatedDeliveryCharge => _pricing.deliveryCharge;
  double get _total => _pricing.grandTotal;

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _selectedAddress = widget.selectedAddress;
    _couponCode = widget.couponCode;
    _couponDiscount = widget.couponDiscount;
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
        _isStoreOpen = status.isAcceptingOrders;
        _storeStatusError = false;
        _deliveryFeeAmount = status.deliveryFee;
        _freeDeliveryThreshold = status.freeDeliveryThreshold;
      });
      if (showClosedSheet && !status.isAcceptingOrders) {
        await _showStoreClosedSheet();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStoreOpen = false;
        _storeStatusError = true;
      });
    }
  }

  Future<void> _showStoreClosedSheet({bool force = false}) async {
    if (!mounted || _storeStatus == null || _storeStatus!.isAcceptingOrders) return;
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
    } catch (_) {}
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
    final mv = context.meatvo;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor:
            isError ? AppThemeColors.error : AppThemeColors.success,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          mv.spacing.md,
          0,
          mv.spacing.md,
          mv.spacing.md + 72,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mv.radii.lg),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String get _loadingMessage => _isOnlinePayment
      ? 'Opening secure payment…'
      : 'Placing your order…';

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
          'We are not accepting orders right now — please check back soon.';
    }
    if (raw.toLowerCase().contains('payment service unavailable') ||
        raw.toLowerCase().contains('failed to initiate payment')) {
      return 'Order saved. Online payment is temporarily unavailable — open My Orders to retry or choose Cash on Delivery next time.';
    }
    if (raw.contains('receiveTimeout') ||
        raw.contains('receive data') ||
        raw.toLowerCase().contains('took longer than') ||
        raw.toLowerCase().contains('connection timed out')) {
      return 'Order placement timed out. Check My Orders — your order may already be placed. If not, try again on a stronger connection.';
    }
    return raw;
  }

  bool _isLikelyTimeout(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('receivetimeout') ||
        raw.contains('receive data') ||
        raw.contains('took longer than') ||
        raw.contains('connection timed out') ||
        raw.contains('timed out');
  }

  void _dismissPlaceOrderError() {
    if (!mounted) return;
    setState(() {
      _isPlacingOrder = false;
      _placeOrderError = null;
    });
  }

  Future<CheckoutQuickPayResult?> _showQuickPay() {
    return CheckoutQuickPaySheet.show(
      context,
      total: _total,
      upiSelection: _upiSelection,
      upiPackageId: _selectedUpiPackageId,
      paymentService: _paymentService,
    );
  }

  void _applyUpiSelection(CheckoutQuickPayResult result) {
    setState(() {
      _upiSelection = result.upiSelection;
      _selectedUpiPackageId = result.upiPackageId;
    });
  }

  Future<void> _onPayViaTap() async {
    final option = await CheckoutPaymentMethodSheet.show(context);
    if (option == null || !mounted) return;

    setState(() => _paymentOption = option);
    await _savePaymentOption(option);

    if (option == CheckoutPaymentOption.online) {
      final result = await _showQuickPay();
      if (result?.confirmed != true || !mounted) return;
      _applyUpiSelection(result!);
      await _placeOrder();
    }
  }

  Future<void> _onPlaceOrderTap() async {
    if (_paymentOption == null) {
      final option = await CheckoutPaymentMethodSheet.show(context);
      if (option == null || !mounted) return;

      setState(() => _paymentOption = option);
      await _savePaymentOption(option);
    }

    if (_paymentOption == CheckoutPaymentOption.online) {
      final result = await _showQuickPay();
      if (result?.confirmed != true || !mounted) return;
      _applyUpiSelection(result!);
    }

    await _placeOrder();
  }

  Future<void> _completeOrderFlow(
    OrderModel order,
    Map<String, dynamic> deliveryAddressJson,
  ) async {
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

    final isOnlineOrder = _isOnlinePayment && serverPayment == 'ONLINE';

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
            checkoutMode: _resolveCashfreeCheckoutMode(),
            upiPackageId: _selectedUpiPackageId,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = false;
      _showSuccessOverlay = true;
    });

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

    setState(() {
      _isPlacingOrder = true;
      _placeOrderError = null;
    });

    final orderStartedAt = DateTime.now();

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

      // Re-validate coupon if one was applied
      double effectiveCouponDiscount = _couponDiscount;
      if (_couponCode != null && _couponCode!.isNotEmpty) {
        final couponResult = await CouponService().validateCoupon(
          _couponCode!,
          cart.subtotal,
        );
        if (!mounted) return;
        if (!couponResult.isValid) {
          final invalidCoupon = _couponCode;
          setState(() {
            _isPlacingOrder = false;
            _couponCode = null;
            _couponDiscount = 0;
          });
          _showMessage(
            'Your coupon "${invalidCoupon ?? ""}" is no longer valid: '
            '${couponResult.errorMessage ?? "Please remove it and try again."}',
          );
          return;
        }
        effectiveCouponDiscount = couponResult.discountAmount;
        if (_couponDiscount != effectiveCouponDiscount) {
          setState(() => _couponDiscount = effectiveCouponDiscount);
        }
      }

      final validation = await _deliveryService.validateDeliveryAddress(
        latitude: _selectedAddress!.latitude!,
        longitude: _selectedAddress!.longitude!,
        skipGeocoding: true,
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
        couponCode: _couponCode,
      );

      if (!mounted) return;
      await _completeOrderFlow(order, deliveryAddressJson);
    } catch (e) {
      if (!mounted) return;

      if (_isLikelyTimeout(e)) {
        final recovered = await _orderService.findRecentlyPlacedOrder(
          since: orderStartedAt,
          paymentMethod: _paymentMethod,
        );
        if (recovered != null && mounted) {
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
          await _completeOrderFlow(recovered, deliveryAddressJson);
          return;
        }
      }

      final message = _friendlyError(e);
      setState(() {
        _isPlacingOrder = true;
        _placeOrderError = message;
      });
      _showMessage(message);
    } finally {
      if (mounted && _isPlacingOrder && _placeOrderError == null) {
        setState(() => _isPlacingOrder = false);
      }
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
    final canPlaceOrder = !_storeStatusError &&
        _isStoreOpen &&
        _selectedAddress != null &&
        _selectedAddress!.latitude != null &&
        _selectedAddress!.longitude != null;

    return Stack(
      children: [
        PopScope(
          canPop: !_isPlacingOrder || _placeOrderError != null,
          child: Scaffold(
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
                'Review & Pay',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mv.textPrimary,
                    ),
              ),
              centerTitle: false,
            ),
            body: _isLoading
                ? const ShimmerLoader.listTile(count: 4)
                : _errorMessage != null
                    ? ErrorStateWidget(
                        title: 'Checkout unavailable',
                        message: _errorMessage,
                        onRetry: _loadAddresses,
                      )
                    : ActiveFlowBackground(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 150),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
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
                                  _buildCheckoutHero(canPlaceOrder),
                                  const SizedBox(height: 20),
                                  CheckoutOrderSummary(
                                    subtotal: _subtotal,
                                    productDiscount: _productDiscount,
                                    couponDiscount: _couponDiscount,
                                    deliveryCharge: _calculatedDeliveryCharge,
                                    total: _total,
                                  ),
                                  const SizedBox(height: 20),
                                  const CheckoutCancellationPolicy(),
                                  const SizedBox(height: 20),
                                  if (_storeStatusError) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: const Color(0xFFF59E0B),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Unable to verify store status. Please try again.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: mv.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  CheckoutDeliverySection(
                                    selectedAddress: _selectedAddress,
                                    isEmptyAddress: _selectedAddress == null,
                                    onChangeAddress: _selectAddress,
                                    onAddAddress: _openAddAddress,
                                    isStoreOpen: _isStoreOpen,
                                    storeClosedMessage: _isStoreOpen
                                        ? null
                                        : (_storeStatus?.displayClosedMessage ??
                                            'We are not accepting orders right now — please check back soon.'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
            bottomNavigationBar: _addresses.isEmpty || _isLoading
                ? null
                : CheckoutPlaceOrderBar(
                    bill: CheckoutBillBreakdown(total: _total),
                    isEnabled: canPlaceOrder,
                    isLoading: _isPlacingOrder,
                    selectedPayment: _paymentOption,
                    onPayViaTap: _onPayViaTap,
                    onPlaceOrder: _onPlaceOrderTap,
                  ),
          ),
        ),
        if (_isPlacingOrder && !_showSuccessOverlay)
          AbsorbPointer(
            absorbing: _placeOrderError == null,
            child: CheckoutLoadingOverlay(
              message: _loadingMessage,
              subtitle: _isOnlinePayment
                  ? 'Complete payment in Cashfree — order confirms only after payment'
                  : 'Confirming availability & creating order',
              errorMessage: _placeOrderError,
              onCancel:
                  _placeOrderError != null ? _dismissPlaceOrderError : null,
            ),
          ),
        if (_showSuccessOverlay)
          CheckoutSuccessOverlay(
            message: _isOnlinePayment
                ? 'Opening secure payment…'
                : 'Your fresh order is on its way.',
          ),
      ],
    );
  }

  Widget _buildCheckoutHero(bool canPlaceOrder) {
    final addressLabel = _selectedAddress?.label.name ?? 'Address pending';
    final paymentLabel = _paymentOption?.label ?? 'Choose payment';

    return ActiveFlowHeroCard(
      eyebrow: 'Review before you place the order',
      title: canPlaceOrder
          ? 'Everything is lined up for payment'
          : 'One more step before we place this order',
      subtitle: canPlaceOrder
          ? 'Confirm the address, review the bill, and pay with your preferred method.'
          : 'Finish the delivery setup below so the order can move straight into confirmation.',
      metrics: [
        ActiveFlowMetricPill(
          label: 'Address',
          value: addressLabel,
          icon: Icons.location_on_outlined,
          inverted: true,
        ),
        ActiveFlowMetricPill(
          label: 'Payment',
          value: paymentLabel,
          icon: Icons.payments_outlined,
          inverted: true,
        ),
        ActiveFlowMetricPill(
          label: 'Total',
          value: '₹${_total.toStringAsFixed(0)}',
          icon: Icons.receipt_long_outlined,
          inverted: true,
        ),
      ],
    );
  }
}
