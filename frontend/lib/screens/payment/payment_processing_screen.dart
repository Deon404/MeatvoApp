import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../orders/order_confirmation_screen.dart';
import 'payment_result_screen.dart';

/// Warm processing screen shown while Cashfree SDK runs + backend confirms payment.
class PaymentProcessingScreen extends StatefulWidget {
  const PaymentProcessingScreen({
    super.key,
    required this.order,
    required this.deliveryAddress,
    required this.paymentService,
    required this.amount,
    this.checkoutMode,
    this.upiPackageId,
  });

  final OrderModel order;
  final Map<String, dynamic> deliveryAddress;
  final PaymentService paymentService;
  final double amount;
  final CashfreeCheckoutMode? checkoutMode;
  final String? upiPackageId;

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();

  Timer? _pollTimer;
  bool _navigated = false;
  bool _sdkStarted = false;
  int _pollAttempts = 0;

  static const _pollInterval = Duration(seconds: 2);
  static const _maxPollAttempts = 15;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPaymentFlow());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollPaymentStatus());
  }

  Future<void> _pollPaymentStatus() async {
    if (_navigated || !mounted) return;
    if (_pollAttempts >= _maxPollAttempts) return;

    _pollAttempts++;

    try {
      final statusData =
          await widget.paymentService.getPaymentStatusForOrder(widget.order.id);
      final status = (statusData['status'] ?? statusData['paymentStatus'])
          ?.toString()
          .toUpperCase();
      if (status != 'SUCCESS' && status != 'PAID') return;

      final orderStatus = (statusData['orderStatus'] ?? statusData['order_status'])
          ?.toString()
          .toUpperCase();

      if (orderStatus == 'CONFIRMED') {
        await _completeSuccess(
          gatewayPaymentId: statusData['gateway_payment_id']?.toString() ??
              statusData['gateway_transaction_id']?.toString(),
        );
        return;
      }

      // Backend may still be confirming — verify order row before showing success.
      final order = await _orderService.getOrderById(widget.order.id);
      if (order.status.toUpperCase() == 'CONFIRMED') {
        await _completeSuccess(
          gatewayPaymentId: statusData['gateway_payment_id']?.toString(),
        );
      }
    } catch (_) {
      // Keep polling until SDK completes or max attempts.
    }
  }

  Future<void> _runPaymentFlow() async {
    if (_sdkStarted || _navigated) return;
    _sdkStarted = true;

    final result = await widget.paymentService.initiatePayment(
      orderId: widget.order.id,
      amount: widget.amount,
      checkoutMode: widget.checkoutMode,
      upiPackageId: widget.upiPackageId,
    );

    if (_navigated || !mounted) return;

    if (result.success) {
      await _completeSuccess(gatewayPaymentId: result.gatewayPaymentId);
    } else if (result.errorCode != 'PAYMENT_PENDING') {
      _goToFailure(result);
    }
  }

  Future<void> _completeSuccess({String? gatewayPaymentId}) async {
    if (_navigated || !mounted) return;

    OrderModel confirmedOrder = widget.order;
    try {
      confirmedOrder = await _orderService.getOrderById(widget.order.id);
    } catch (_) {
      // Use original order if refresh fails.
    }

    final orderStatus = confirmedOrder.status.toUpperCase();
    final paymentStatus = confirmedOrder.paymentStatus?.toUpperCase() ?? '';
    if (orderStatus != 'CONFIRMED' && paymentStatus != 'PAID') {
      // Payment row may show SUCCESS before order confirm finishes — keep waiting.
      return;
    }

    if (_navigated || !mounted) return;
    _navigated = true;
    _pollTimer?.cancel();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderConfirmationScreen(
          order: confirmedOrder,
          deliveryAddress: widget.deliveryAddress,
          paymentId: gatewayPaymentId,
          isOnlinePaymentSuccess: true,
        ),
      ),
    );
  }

  void _goToFailure(PaymentResult result) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _pollTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          order: widget.order,
          deliveryAddress: widget.deliveryAddress,
          errorMessage: result.errorMessage,
          errorCode: result.errorCode,
          onRetry: () async {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PaymentProcessingScreen(
                  order: widget.order,
                  deliveryAddress: widget.deliveryAddress,
                  paymentService: widget.paymentService,
                  amount: widget.amount,
                  checkoutMode: widget.checkoutMode,
                  upiPackageId: widget.upiPackageId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: mv.surfaceWarm,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(mv.spacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _pulseController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: MeatvoColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: mv.brandPrimary,
                        size: 36,
                      ),
                    ),
                  ),
                  SizedBox(height: mv.spacing.lg),
                  Text(
                    'Confirming your payment…',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mv.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: mv.spacing.sm),
                  Text(
                    'Complete payment in the secure Cashfree checkout.\n'
                    'UPI opens your installed payment app when available.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: mv.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: mv.spacing.xl),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: mv.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
