import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/address_model.dart';
import '../../models/cart_model.dart';
import '../../models/delivery_slot_model.dart';
import '../../models/order_model.dart';
import '../../services/address_service.dart';
import '../../services/cart_service.dart';
import '../../services/delivery_service.dart';
import '../../services/delivery_slot_api_service.dart';
import '../../services/express_delivery_service.dart';
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
import '../address/address_form_screen.dart';
import '../orders/order_confirmation_screen.dart';
import '../payment/payment_result_screen.dart';
import '../../utils/responsive_helper.dart';

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
  final DeliverySlotApiService _slotService = DeliverySlotApiService();
  final PaymentService _paymentService = PaymentService();

  AddressModel? _selectedAddress;
  CartModel? _cart;
  List<AddressModel> _addresses = [];
  List<DeliverySlotModel> _deliverySlots = [];
  DeliverySlotModel? _selectedSlot;
  bool _isLoading = true;
  bool _isLoadingSlots = true;
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
    _loadDeliverySlots();
    _syncCartFromServer();
    _loadSavedPaymentOption();
  }

  DeliverySlotModel? _firstAvailableSlot(List<DeliverySlotModel> slots) {
    for (final slot in slots) {
      if (slot.available) return slot;
    }
    return null;
  }

  void _applySlotSelection(List<DeliverySlotModel> slots) {
    final bookable = _bookableSlots(slots);
    _deliverySlots = slots;
    _selectedSlot = _firstAvailableSlot(bookable) ??
        (bookable.isNotEmpty
            ? bookable.first
            : (slots.isNotEmpty
                ? slots.first
                : DeliverySlotModel.expressFallback()));
  }

  String _slotOrderLabel(DeliverySlotModel slot) {
    return '${slot.name} · ${slot.time} · ${slot.dateLabel}';
  }

  List<DeliverySlotModel> _bookableSlots(List<DeliverySlotModel> slots) {
    return slots.where((slot) => slot.available).toList();
  }

  Future<void> _loadDeliverySlots() async {
    if (mounted) setState(() => _isLoadingSlots = true);

    try {
      final slots = await _slotService.fetchSlots();
      if (!mounted) return;

      if (slots.isEmpty) {
        setState(() {
          _applySlotSelection([DeliverySlotModel.expressFallback()]);
          _isLoadingSlots = false;
        });
        return;
      }

      setState(() {
        _applySlotSelection(slots);
        _isLoadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applySlotSelection([DeliverySlotModel.expressFallback()]);
        _isLoadingSlots = false;
      });
    }
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
    if (raw.toLowerCase().contains('delivery slot')) {
      return 'Selected delivery slot is no longer available. Please choose another.';
    }
    if (raw.toLowerCase().contains('payment service unavailable') ||
        raw.toLowerCase().contains('failed to initiate payment')) {
      return 'Order saved. Online payment is temporarily unavailable — open My Orders to retry or choose Cash on Delivery next time.';
    }
    return raw;
  }

  Future<void> _placeOrder() async {
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

    final closedMessage = ExpressDeliveryService.storeClosedMessage();
    if (closedMessage != null) {
      _showMessage(closedMessage);
      return;
    }

    final selectedSlot = _selectedSlot;
    if (selectedSlot == null) {
      _showMessage('Please select a delivery slot');
      return;
    }
    if (!selectedSlot.available) {
      _showMessage('Selected delivery slot is no longer available');
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

      var slotForOrder = selectedSlot;
      if (selectedSlot.id > 0) {
        try {
          final fresh = await _slotService.getSlotById(selectedSlot.id);
          if (!fresh.available) {
            if (!mounted) return;
            setState(() => _isPlacingOrder = false);
            _showMessage(
              'Selected delivery slot is no longer available. Please choose another.',
            );
            await _loadDeliverySlots();
            return;
          }
          slotForOrder = fresh;
        } catch (_) {
          // Proceed with the cached selection if re-fetch fails.
        }
      }

      final deliverySlotLabel = _slotOrderLabel(slotForOrder);
      final slotMeta = slotForOrder.toOrderPayload();
      final deliverySlotId =
          slotForOrder.id > 0 ? slotForOrder.id : null;

      final order = await _orderService.createOrder(
        cart: cart,
        deliveryAddress: deliveryAddressJson,
        deliverySlot: deliverySlotLabel,
        deliverySlotId: deliverySlotId,
        deliverySlotMeta: slotMeta,
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
        try {
          await _paymentService.initiatePayment(
            orderId: order.id,
            amount: order.finalAmount > 0 ? order.finalAmount : _total,
          );
        } catch (e) {
          if (!mounted) return;
          setState(() => _isPlacingOrder = false);
          _showMessage(_friendlyError(e));
          return;
        }

        if (!mounted) return;
        setState(() => _isPlacingOrder = false);

        // Backend clears cart on order create — sync local badge/state.
        try {
          await _cartService.getCart();
        } catch (_) {}

        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _PaymentStatusPoller(
              order: order,
              deliverySlot: deliverySlotLabel,
              deliveryAddress: deliveryAddressJson,
              paymentService: _paymentService,
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
            deliverySlot: deliverySlotLabel,
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

  Future<void> _openAddAddress() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
    if (!mounted) return;
    if (result != true) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Address saved successfully')),
    );
    await _loadAddresses();
  }

  Future<void> _selectAddress() async {
    final result = await showModalBottomSheet<AddressModel>(
      context: context,
      backgroundColor: AppThemeColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusXl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (sheetContext, scrollController) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            sheetBottomPadding(sheetContext, extra: AppSpacing.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppThemeColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Select delivery address',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: _addresses.map((address) {
                    final isSelected = _selectedAddress?.id == address.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Material(
                        color: isSelected
                            ? AppThemeColors.primaryLight.withValues(alpha: 0.25)
                            : AppThemeColors.white,
                        borderRadius:
                            BorderRadius.circular(AppRadius.radiusLg),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context, address);
                          },
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusLg),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.radiusLg),
                              border: Border.all(
                                color: isSelected
                                    ? AppThemeColors.primary
                                    : AppThemeColors.border,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  address.label == AddressLabel.home
                                      ? Icons.home_rounded
                                      : address.label == AddressLabel.work
                                          ? Icons.work_rounded
                                          : Icons.location_on_rounded,
                                  color: AppThemeColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.label.displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address.displayAddress,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  AppThemeColors.textSecondary,
                                              height: 1.4,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppThemeColors.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openAddAddress();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add new address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedAddress = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeOpen = ExpressDeliveryService.isStoreOpen();
    // Only enable order placement if address has valid coordinates
    final hasAvailableSlot = _selectedSlot != null && _selectedSlot!.available;
    final canPlaceOrder = _selectedAddress != null &&
        _selectedAddress!.latitude != null &&
        _selectedAddress!.longitude != null &&
        storeOpen &&
        hasAvailableSlot &&
        !_isLoadingSlots;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AppThemeColors.background,
          appBar: AppBar(
            backgroundColor: AppThemeColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppThemeColors.textPrimary,
              ),
              onPressed: _isPlacingOrder ? null : () => Navigator.pop(context),
            ),
            title: Text(
              'Checkout',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
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
                              deliverySlots: _deliverySlots,
                              selectedSlot: _selectedSlot,
                              onSlotSelected: (slot) {
                                setState(() => _selectedSlot = slot);
                              },
                              isLoadingSlots: _isLoadingSlots,
                            ),
                            if (!storeOpen) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                ExpressDeliveryService.storeClosedMessage() ??
                                    'Store is currently closed',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppThemeColors.error),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
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
                ? 'Redirecting to secure payment…'
                : 'Your fresh order is on its way.',
          ),
      ],
    );
  }
}

/// Polls PhonePe payment status after user returns from external browser.
class _PaymentStatusPoller extends StatefulWidget {
  final OrderModel order;
  final String deliverySlot;
  final Map<String, dynamic> deliveryAddress;
  final PaymentService paymentService;

  const _PaymentStatusPoller({
    required this.order,
    required this.deliverySlot,
    required this.deliveryAddress,
    required this.paymentService,
  });

  @override
  State<_PaymentStatusPoller> createState() => _PaymentStatusPollerState();
}

class _PaymentStatusPollerState extends State<_PaymentStatusPoller> {
  bool _checking = false;
  int _attempt = 0;
  static const _maxAttempts = 3;
  static const _retryDelay = Duration(seconds: 2);

  Future<void> _checkStatus({bool navigateOnPending = true}) async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      for (var i = 0; i < _maxAttempts; i++) {
        _attempt = i + 1;
        if (i > 0) await Future<void>.delayed(_retryDelay);

        final statusData = await widget.paymentService
            .getPaymentStatusForOrder(widget.order.id);
        final status = (statusData['status'] ?? statusData['paymentStatus'])
            ?.toString()
            .toUpperCase();
        final isSuccess = status == 'SUCCESS' || status == 'PAID';

        if (isSuccess) {
          if (!mounted) return;
          _goToResult(isSuccess: true, statusData: statusData);
          return;
        }

        if (status == 'PENDING' && navigateOnPending && i < _maxAttempts - 1) {
          continue;
        }

        if (!mounted) return;
        _goToResult(
          isSuccess: false,
          statusData: statusData,
          status: status,
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      _goToResult(isSuccess: false, errorMessage: e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _goToResult({
    required bool isSuccess,
    Map<String, dynamic>? statusData,
    String? status,
    String? errorMessage,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          isSuccess: isSuccess,
          order: widget.order,
          paymentId: statusData?['gateway_transaction_id']?.toString(),
          deliverySlot: widget.deliverySlot,
          deliveryAddress: widget.deliveryAddress,
          errorMessage: isSuccess
              ? null
              : errorMessage ??
                  'Payment is ${status ?? 'pending'}. Tap retry if you completed payment.',
          onRetry: isSuccess
              ? null
              : () {
                  Navigator.of(context).pop();
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppThemeColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppThemeColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppThemeColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Complete payment in PhonePe',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Finish payment in the browser, then return here and tap the button below.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _checking ? null : () => _checkStatus(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppThemeColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.radiusPill),
                    ),
                  ),
                  child: _checking
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppThemeColors.white,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Checking… ($_attempt/$_maxAttempts)'),
                          ],
                        )
                      : const Text("I've completed payment"),
                ),
              ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

