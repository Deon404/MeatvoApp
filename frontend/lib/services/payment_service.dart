import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../config/env_config.dart';
import 'api_service.dart';

/// Payment Service — custom Node.js backend + UPI deep links
class PaymentService {
  final ApiService _api = ApiService();

  Function(Map<String, dynamic>)? _onSuccess;
  Function(String)? _onFailure;
  bool _isInitialized = false;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ PaymentService initialized (custom backend)');
  }

  // ── Backend payment initiation ────────────────────────────────────────────

  /// Initiate payment via backend — returns paymentUrl + transactionId.
  Future<Map<String, dynamic>> _initiatePaymentRequest({
    required String orderId,
    required double amount,
    required String phone,
  }) async {
    try {
      final res = await _api.post('/payments/initiate', data: {
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

  /// Verify payment transaction via backend.
  Future<Map<String, dynamic>> _verifyPaymentRequest(String transactionId) async {
    try {
      final res = await _api.post('/payments/verify', data: {
        'transactionId': transactionId,
      });
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to verify payment');
      }
      return Map<String, dynamic>.from(res.data['data'] as Map);
    } catch (_) {
      rethrow;
    }
  }

  // ── Legacy method (kept for screen compatibility) ──────────────────────────

  /// Initiate payment using backend and launch paymentUrl externally.
  /// POST /payments/initiate
  /// body: { orderId, amount, phone }
  /// response: { data: { paymentUrl, transactionId } }
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

      final paymentUrl = data['paymentUrl'] as String?;
      final transactionId = data['transactionId'] as String?;

      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('✅ Payment URL opened: $paymentUrl');
          // Caller must manually verify after returning from payment app
        } else {
          throw Exception('Cannot open payment URL');
        }
      }

      // Notify success with transaction details
      _onSuccess?.call({
        'transactionId': transactionId ?? '',
        'orderId': orderId,
        'status': 'initiated',
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
  /// POST /payments/verify
  /// body: { transactionId }
  /// response: { data: { success, status } }
  Future<Map<String, dynamic>> verifyPayment({
    required String transactionId,
  }) =>
      _verifyPaymentRequest(transactionId);

  /// GET /payments/:orderId/status
  Future<Map<String, dynamic>> getPaymentStatusForOrder(String orderId) async {
    try {
      final res = await _api.get('/payments/$orderId/status');
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

  // ── UPI deep-link payment (no merchant account needed) ───────────────────

  Future<void> initiateUPIPayment({
    required String orderId,
    required double amount,
    required String customerName,
    required String? phonepeNumber,
    required String? upiId,
    required String? merchantUPIId,
    required String? merchantPhoneNumber,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    try {
      final amountString = amount.toStringAsFixed(2);
      final paymentNote = 'Payment for Order #$orderId';

      String upiUrl = '';

      if (merchantPhoneNumber != null && merchantPhoneNumber.isNotEmpty) {
        final clean = merchantPhoneNumber.replaceAll(RegExp(r'[\s\-]'), '');
        upiUrl =
            'phonepe://pay?pa=$clean&pn=Meatvo&am=$amountString&cu=INR&tn=$paymentNote';
      } else if (merchantUPIId != null && merchantUPIId.isNotEmpty) {
        upiUrl =
            'upi://pay?pa=$merchantUPIId&pn=Meatvo&am=$amountString&cu=INR&tn=$paymentNote';
      } else if (EnvConfig.merchantPhoneNumber.isNotEmpty) {
        final clean =
            EnvConfig.merchantPhoneNumber.replaceAll(RegExp(r'[\s\-]'), '');
        upiUrl =
            'phonepe://pay?pa=$clean&pn=Meatvo&am=$amountString&cu=INR&tn=$paymentNote';
      } else if (phonepeNumber != null && phonepeNumber.isNotEmpty) {
        final clean = phonepeNumber.replaceAll(RegExp(r'[\s\-]'), '');
        upiUrl =
            'phonepe://pay?pa=$clean&pn=$customerName&am=$amountString&cu=INR&tn=$paymentNote';
      } else if (upiId != null && upiId.isNotEmpty) {
        upiUrl =
            'upi://pay?pa=$upiId&pn=$customerName&am=$amountString&cu=INR&tn=$paymentNote';
      } else {
        throw Exception(
            'Merchant phone number, UPI ID, ya PhonePe number dena zaroori hai');
      }

      final uri = Uri.parse(upiUrl);
      if (await canLaunchUrl(uri)) {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          debugPrint('✅ UPI payment app opened successfully');
        } else {
          throw Exception('Could not open your UPI payment app.');
        }
      } else {
        throw Exception('No UPI payment app found on this device.');
      }
    } catch (e) {
      debugPrint('❌ Error initiating UPI payment: $e');
      _onFailure?.call(e.toString());
    }
  }

  Future<void> initiatePhonePeDirectPayment({
    required String orderId,
    required double amount,
    required String customerName,
    required String? phonepeNumber,
    required String? merchantPhoneNumber,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onFailure,
  }) async {
    await initiateUPIPayment(
      orderId: orderId,
      amount: amount,
      customerName: customerName,
      phonepeNumber: phonepeNumber,
      upiId: null,
      merchantUPIId: null,
      merchantPhoneNumber: merchantPhoneNumber,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  Future<void> verifyManualPayment({
    required String orderId,
    required String transactionId,
    required String? upiReferenceId,
  }) async {
    try {
      final verification = await _verifyPaymentRequest(transactionId);
      if (verification['success'] == true) {
        _onSuccess?.call({
          'transactionId': transactionId,
          'upiReferenceId': upiReferenceId,
          'status': verification['status'] ?? 'completed',
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
