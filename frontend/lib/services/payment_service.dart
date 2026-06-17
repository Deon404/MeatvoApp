import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'api_service.dart';

/// Payment Service — custom Node.js backend + Cashfree hosted checkout
class PaymentService {
  final ApiService _api = ApiService();

  Function(Map<String, dynamic>)? _onSuccess;
  Function(String)? _onFailure;
  bool _isInitialized = false;

  String? _paymentSessionId;
  String? _cfOrderId;

  String? get paymentSessionId => _paymentSessionId;
  String? get cfOrderId => _cfOrderId;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ PaymentService initialized (Cashfree backend)');
  }

  // ── Backend payment initiation ────────────────────────────────────────────

  /// Initiate payment via backend — returns payment_session_id + cf_order_id.
  Future<Map<String, dynamic>> _initiatePaymentRequest({
    required String orderId,
    required double amount,
    required String phone,
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
          'Failed to initiate payment: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to initiate payment: $e');
    }
  }

  /// Verify payment via backend (Cashfree).
  Future<Map<String, dynamic>> _verifyPaymentRequest(String orderId) async {
    try {
      final res = await _api.post('/payments/cashfree/verify', data: {
        'orderId': int.tryParse(orderId) ?? orderId,
      });
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to verify payment');
      }
      return Map<String, dynamic>.from(res.data['data'] as Map);
    } catch (_) {
      rethrow;
    }
  }

  // ── Cashfree hosted checkout ────────────────────────────────────────────────

  /// Opens Cashfree native checkout (UPI via Web Checkout SDK).
  Future<void> openCashfreeCheckout(
      String paymentSessionId, String orderId) async {
    try {
      var session = CFSessionBuilder()
          .setEnvironment(CFEnvironment.SANDBOX) // change to PRODUCTION when live
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
        (String orderId) async {
          debugPrint('✅ Cashfree payment success: $orderId');
          await verifyPayment(transactionId: orderId);
        },
        (CFErrorResponse error, String orderId) {
          debugPrint(
              '❌ Cashfree payment error: ${error.getMessage()} for $orderId');
        },
      );

      cfPaymentGatewayService.doPayment(cfWebCheckout);
    } catch (e) {
      debugPrint('❌ Cashfree checkout error: $e');
      rethrow;
    }
  }

  // ── Legacy method (kept for screen compatibility) ──────────────────────────

  /// Initiate payment using backend and launch Cashfree hosted checkout.
  /// POST /payments/cashfree/initiate
  /// body: { orderId }
  /// response: { data: { payment_session_id, cf_order_id, orderId } }
  ///
  /// Backward compatibility: old fields/callbacks are still accepted.
  Future<Map<String, dynamic>> initiatePayment({
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

      final data = await _initiatePaymentRequest(
        orderId: orderId,
        amount: amount,
        phone: phone ?? customerPhone ?? '',
      );

      final paymentSessionId = data['payment_session_id'] as String?;
      final cfOrderId = data['cf_order_id'] as String?;

      _paymentSessionId = paymentSessionId;
      _cfOrderId = cfOrderId;

      if (paymentSessionId != null && paymentSessionId.isNotEmpty) {
        await openCashfreeCheckout(paymentSessionId, orderId.toString());
      } else {
        throw Exception('Missing payment session from backend');
      }

      _onSuccess?.call({
        'transactionId': cfOrderId ?? '',
        'orderId': orderId,
        'status': 'initiated',
        'payment_session_id': paymentSessionId,
        'cf_order_id': cfOrderId,
        ...data,
      });
      return data;
    } catch (e) {
      debugPrint('❌ Payment initiation error: $e');
      _onFailure?.call(e.toString());
      rethrow;
    }
  }

  // ── Verify payment ─────────────────────────────────────────────────────────

  /// Verify payment via backend.
  /// POST /payments/cashfree/verify
  /// body: { orderId }
  /// response: { data: { verified, status } }
  ///
  /// [transactionId] is kept for backward compatibility — pass the order ID.
  Future<Map<String, dynamic>> verifyPayment({
    required String transactionId,
  }) =>
      _verifyPaymentRequest(transactionId);

  /// GET /payments/cashfree/:orderId/status
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
          'Failed to fetch payment status: ${e.response?.data?['message'] ?? e.message}');
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
      debugPrint('❌ Error verifying manual payment: $e');
      _onFailure?.call('Error verifying payment: $e');
    }
  }

  void dispose() {}
}
