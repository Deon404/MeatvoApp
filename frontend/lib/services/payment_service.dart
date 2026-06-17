import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

import '../config/env_config.dart';
import 'api_service.dart';

/// Result of a Cashfree payment attempt (SDK + backend verify).
class PaymentResult {
  const PaymentResult({
    required this.success,
    required this.orderId,
    this.gatewayPaymentId,
    this.status,
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final String orderId;
  final String? gatewayPaymentId;
  final String? status;
  final String? errorCode;
  final String? errorMessage;
}

/// Payment Service — Node.js backend + Cashfree Web Checkout SDK.
class PaymentService {
  final ApiService _api = ApiService();

  Function(Map<String, dynamic>)? _onSuccess;
  Function(String)? _onFailure;
  bool _isInitialized = false;

  String? _paymentSessionId;
  String? _cfOrderId;

  String? get paymentSessionId => _paymentSessionId;
  String? get cfOrderId => _cfOrderId;

  CFEnvironment get _cashfreeEnvironment =>
      EnvConfig.cashfreeUseProduction
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint(
      'PaymentService initialized (Cashfree ${_cashfreeEnvironment.name})',
    );
  }

  Future<Map<String, dynamic>> _initiatePaymentRequest({
    required String orderId,
  }) async {
    try {
      final res = await _api.post('/payments/cashfree/initiate', data: {
        'orderId': int.tryParse(orderId) ?? orderId,
      });

      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to initiate payment');
      }

      return Map<String, dynamic>.from(res.data['data'] as Map);
    } on DioException catch (e) {
      throw Exception(
        'Failed to initiate payment: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e) {
      throw Exception('Failed to initiate payment: $e');
    }
  }

  Future<Map<String, dynamic>> _verifyPaymentRequest(String orderId) async {
    final res = await _api.post('/payments/cashfree/verify', data: {
      'orderId': int.tryParse(orderId) ?? orderId,
    });
    if (res.data['success'] != true) {
      throw Exception(res.data['message'] ?? 'Failed to verify payment');
    }
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  String _mapCashfreeError(CFErrorResponse error) {
    final message = error.getMessage()?.trim() ?? '';
    final lower = message.toLowerCase();
    if (lower.contains('cancel') || lower.contains('dismiss')) {
      return 'PAYMENT_CANCELLED';
    }
    if (lower.contains('network')) return 'NETWORK_ERROR';
    return 'PAYMENT_DECLINED';
  }

  /// Opens Cashfree native checkout and completes when SDK callback fires.
  Future<PaymentResult> _openCashfreeCheckout(
    String paymentSessionId,
    String orderId,
  ) async {
    final completer = Completer<PaymentResult>();

    var session = CFSessionBuilder()
        .setEnvironment(_cashfreeEnvironment)
        .setOrderId(orderId)
        .setPaymentSessionId(paymentSessionId)
        .build();

    var theme = CFThemeBuilder()
        .setNavigationBarBackgroundColorColor('#C8102E')
        .setNavigationBarTextColor('#FFFFFF')
        .setPrimaryFont('Poppins')
        .setSecondaryFont('Poppins')
        .setPrimaryTextColor('#1A1A1A')
        .setSecondaryTextColor('#666666')
        .setBackgroundColor('#FAF9F7')
        .setButtonBackgroundColor('#C8102E')
        .setButtonTextColor('#FFFFFF')
        .build();

    var cfWebCheckout = CFWebCheckoutPaymentBuilder()
        .setSession(session)
        .setTheme(theme)
        .build();

    final cfPaymentGatewayService = CFPaymentGatewayService();
    cfPaymentGatewayService.setCallback(
      (String callbackOrderId) async {
        if (completer.isCompleted) return;
        try {
          final verification =
              await _verifyPaymentRequest(orderId);
          final verified = verification['verified'] == true ||
              verification['status']?.toString().toUpperCase() == 'SUCCESS';
          if (!verified) {
            completer.complete(
              PaymentResult(
                success: false,
                orderId: orderId,
                status: verification['status']?.toString(),
                errorCode: 'PAYMENT_PENDING',
                errorMessage: 'Payment verification pending. Please wait.',
              ),
            );
            return;
          }
          completer.complete(
            PaymentResult(
              success: true,
              orderId: orderId,
              gatewayPaymentId:
                  verification['gateway_payment_id']?.toString() ??
                  callbackOrderId,
              status: verification['status']?.toString() ?? 'SUCCESS',
            ),
          );
        } catch (e) {
          completer.complete(
            PaymentResult(
              success: false,
              orderId: orderId,
              errorCode: 'NETWORK_ERROR',
              errorMessage: e.toString(),
            ),
          );
        }
      },
      (CFErrorResponse error, String callbackOrderId) {
        if (completer.isCompleted) return;
        final code = _mapCashfreeError(error);
        completer.complete(
          PaymentResult(
            success: false,
            orderId: orderId,
            errorCode: code,
            errorMessage: error.getMessage() ?? 'Payment failed',
          ),
        );
      },
    );

    cfPaymentGatewayService.doPayment(cfWebCheckout);
    return completer.future;
  }

  /// Initiate payment via backend and launch Cashfree checkout.
  /// Completes when the SDK callback + verify finish (or user cancels).
  Future<PaymentResult> initiatePayment({
    required String orderId,
    required double amount,
    String? phone,
    String? userId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    Function(Map<String, dynamic>)? onSuccess,
    Function(String)? onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    try {
      if (!_isInitialized) await initialize();

      final data = await _initiatePaymentRequest(orderId: orderId);

      final paymentSessionId = data['payment_session_id'] as String?;
      final cfOrderId = data['cf_order_id'] as String?;

      _paymentSessionId = paymentSessionId;
      _cfOrderId = cfOrderId;

      if (paymentSessionId == null || paymentSessionId.isEmpty) {
        throw Exception('Missing payment session from backend');
      }

      final result = await _openCashfreeCheckout(
        paymentSessionId,
        orderId.toString(),
      );

      if (result.success) {
        _onSuccess?.call({
          'transactionId': result.gatewayPaymentId ?? cfOrderId ?? '',
          'orderId': orderId,
          'status': result.status ?? 'SUCCESS',
          'payment_session_id': paymentSessionId,
          'cf_order_id': cfOrderId,
          ...data,
        });
      } else {
        _onFailure?.call(result.errorMessage ?? 'Payment failed');
      }

      return result;
    } catch (e) {
      debugPrint('Payment initiation error: $e');
      _onFailure?.call(e.toString());
      return PaymentResult(
        success: false,
        orderId: orderId,
        errorMessage: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String transactionId,
  }) =>
      _verifyPaymentRequest(transactionId);

  Future<Map<String, dynamic>> getPaymentStatusForOrder(String orderId) async {
    try {
      final res = await _api.get('/payments/cashfree/$orderId/status');
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to fetch payment status');
      }
      final data = res.data['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw Exception(
        'Failed to fetch payment status: ${e.response?.data?['message'] ?? e.message}',
      );
    }
  }

  Future<String?> getPaymentStatus(String orderId) async {
    final data = await getPaymentStatusForOrder(orderId);
    return data['status']?.toString();
  }

  Future<void> verifyManualPayment({
    required String orderId,
    required String transactionId,
    required String? upiReferenceId,
  }) async {
    try {
      final verification = await _verifyPaymentRequest(orderId);
      if (verification['verified'] == true ||
          verification['status']?.toString().toUpperCase() == 'SUCCESS') {
        _onSuccess?.call({
          'transactionId': transactionId,
          'upiReferenceId': upiReferenceId,
          'status': verification['status'] ?? 'SUCCESS',
        });
      } else {
        _onFailure?.call('Payment verification failed');
      }
    } catch (e) {
      debugPrint('Error verifying manual payment: $e');
      _onFailure?.call('Error verifying payment: $e');
    }
  }

  void dispose() {}
}
