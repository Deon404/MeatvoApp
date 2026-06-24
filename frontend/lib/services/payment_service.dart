import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfupi/cfupiutils.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env_config.dart';
import 'api_service.dart';
import 'error_tracking_service.dart';

/// Installed UPI app returned by Cashfree [CFUPIUtils.getUPIApps].
class InstalledUpiApp {
  const InstalledUpiApp({
    required this.packageId,
    required this.displayName,
  });

  final String packageId;
  final String displayName;

  factory InstalledUpiApp.fromMap(Map<dynamic, dynamic> map) {
    final packageId = map['id']?.toString().trim() ?? '';
    final displayName = map['displayName']?.toString().trim();
    return InstalledUpiApp(
      packageId: packageId,
      displayName: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : _labelForPackage(packageId),
    );
  }

  static String _labelForPackage(String packageId) {
    final lower = packageId.toLowerCase();
    if (lower.contains('google') || lower.contains('paisa')) return 'GPay';
    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('paytm')) return 'Paytm';
    if (lower.contains('bhim')) return 'BHIM';
    if (packageId.isEmpty) return 'UPI';
    return packageId.split('.').last;
  }
}

/// How the Cashfree SDK should collect payment.
enum CashfreeCheckoutMode {
  /// Native Android UPI app picker (INTENT_WITH_UI).
  upiIntentPicker,

  /// Launch a specific installed UPI app (INTENT + package id).
  upiApp,

  /// Hosted WebView checkout for cards/wallets/more options.
  webCheckout,
}

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

/// Payment Service — Node.js backend + Cashfree SDK (UPI intent + web fallback).
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
      'PaymentService initialized (Cashfree ${_cashfreeEnvironment.name}, '
      'env=${EnvConfig.cashfreeEnv.isNotEmpty ? EnvConfig.cashfreeEnv : EnvConfig.appEnv})',
    );
  }

  /// Returns UPI apps installed on the device (Android). Empty on web/iOS.
  Future<List<InstalledUpiApp>> getInstalledUpiApps() async {
    try {
      final raw = await CFUPIUtils().getUPIApps();
      if (raw == null || raw.isEmpty) return const [];

      return raw
          .whereType<Map>()
          .map((entry) => InstalledUpiApp.fromMap(entry))
          .where((app) => app.packageId.isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('Failed to load installed UPI apps: $e');
      await ErrorTrackingService.captureException(
        e,
        stackTrace: st,
        tag: 'cashfree_upi_apps',
      );
      return const [];
    }
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

  ({String code, String message}) _mapCashfreeError(CFErrorResponse error) {
    final message = error.getMessage()?.trim() ?? '';
    final lower = message.toLowerCase();

    if (lower.contains('cancel') || lower.contains('dismiss')) {
      return (code: 'PAYMENT_CANCELLED', message: message.isNotEmpty ? message : 'Payment cancelled');
    }
    if (lower.contains('network')) {
      return (code: 'NETWORK_ERROR', message: message.isNotEmpty ? message : 'Network error');
    }

    final sdkCode = error.getCode()?.trim();
    if (sdkCode != null && sdkCode.isNotEmpty) {
      return (
        code: sdkCode.toUpperCase(),
        message: message.isNotEmpty ? message : sdkCode,
      );
    }

    return (
      code: 'PAYMENT_DECLINED',
      message: message.isNotEmpty ? message : 'Payment was declined',
    );
  }

  Future<void> _logCashfreeError(CFErrorResponse error, String orderId) async {
    // Force print even in release mode for debugging (remove after root-cause found).
    print('=== CASHFREE ERROR ===');
    print('Message: ${error.getMessage()}');
    print('Code: ${error.getCode()}');
    print('Type: ${error.getType()}');
    print('Status: ${error.getStatus()}');
    print('Environment: $_cashfreeEnvironment');
    print('OrderId: $orderId');
    print('=== END CASHFREE ERROR ===');

    final details = <String, String?>{
      'orderId': orderId,
      'message': error.getMessage(),
      'code': error.getCode(),
      'type': error.getType(),
      'status': error.getStatus(),
      'cashfreeEnv': EnvConfig.cashfreeEnv.isNotEmpty
          ? EnvConfig.cashfreeEnv
          : EnvConfig.appEnv,
    };

    debugPrint('Cashfree SDK onError: $details');

    await ErrorTrackingService.captureMessage(
      'Cashfree SDK error: ${error.getMessage() ?? "unknown"}',
      level: SentryLevel.warning,
      context: details.map((key, value) => MapEntry(key, value ?? '')),
      tag: 'cashfree_sdk',
    );
  }

  CFSession _buildSession(String paymentSessionId, String orderId) {
    return CFSessionBuilder()
        .setEnvironment(_cashfreeEnvironment)
        .setOrderId(orderId)
        .setPaymentSessionId(paymentSessionId)
        .build();
  }

  CFTheme _buildTheme() {
    return CFThemeBuilder()
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
  }

  Future<PaymentResult> _runCashfreePayment({
    required String paymentSessionId,
    required String orderId,
    required CashfreeCheckoutMode mode,
    String? upiPackageId,
  }) async {
    final completer = Completer<PaymentResult>();
    final session = _buildSession(paymentSessionId, orderId);

    final cfPaymentGatewayService = CFPaymentGatewayService();
    cfPaymentGatewayService.setCallback(
      (String callbackOrderId) async {
        if (completer.isCompleted) return;
        try {
          final verification = await _verifyPaymentRequest(orderId);
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
      (CFErrorResponse error, String callbackOrderId) async {
        if (completer.isCompleted) return;
        await _logCashfreeError(error, orderId);
        final mapped = _mapCashfreeError(error);
        completer.complete(
          PaymentResult(
            success: false,
            orderId: orderId,
            errorCode: mapped.code,
            errorMessage: mapped.message,
          ),
        );
      },
    );

    switch (mode) {
      case CashfreeCheckoutMode.webCheckout:
        final webCheckout = CFWebCheckoutPaymentBuilder()
            .setSession(session)
            .setTheme(_buildTheme())
            .build();
        cfPaymentGatewayService.doPayment(webCheckout);
      case CashfreeCheckoutMode.upiIntentPicker:
        final upi = CFUPIBuilder()
            .setChannel(CFUPIChannel.INTENT_WITH_UI)
            .build();
        final upiPayment =
            CFUPIPaymentBuilder().setSession(session).setUPI(upi).build();
        cfPaymentGatewayService.doPayment(upiPayment);
      case CashfreeCheckoutMode.upiApp:
        final packageId = upiPackageId?.trim() ?? '';
        if (packageId.isEmpty) {
          return _runCashfreePayment(
            paymentSessionId: paymentSessionId,
            orderId: orderId,
            mode: CashfreeCheckoutMode.upiIntentPicker,
          );
        }
        final upi = CFUPIBuilder()
            .setChannel(CFUPIChannel.INTENT)
            .setUPIID(packageId)
            .build();
        final upiPayment =
            CFUPIPaymentBuilder().setSession(session).setUPI(upi).build();
        cfPaymentGatewayService.doPayment(upiPayment);
    }

    return completer.future;
  }

  CashfreeCheckoutMode _resolveCheckoutMode({
    CashfreeCheckoutMode? preferredMode,
    String? upiPackageId,
  }) {
    // Explicit web checkout request — honor it
    if (preferredMode == CashfreeCheckoutMode.webCheckout) {
      return CashfreeCheckoutMode.webCheckout;
    }

    // Explicit specific UPI app — honor it
    if (preferredMode == CashfreeCheckoutMode.upiApp &&
        upiPackageId != null &&
        upiPackageId.trim().isNotEmpty) {
      return CashfreeCheckoutMode.upiApp;
    }

    // Android default: always UPI intent picker
    // DO NOT call getInstalledUpiApps() — this was causing silent
    // fallback to webCheckout when SDK couldn't detect apps
    if (defaultTargetPlatform == TargetPlatform.android) {
      return CashfreeCheckoutMode.upiIntentPicker;
    }

    // iOS / other: web checkout
    return CashfreeCheckoutMode.webCheckout;
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
    CashfreeCheckoutMode? checkoutMode,
    String? upiPackageId,
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

      final mode = _resolveCheckoutMode(
        preferredMode: checkoutMode,
        upiPackageId: upiPackageId,
      );

      debugPrint(
        'Launching Cashfree checkout mode=$mode '
        'env=${_cashfreeEnvironment.name} orderId=$orderId',
      );

      final result = await _runCashfreePayment(
        paymentSessionId: paymentSessionId,
        orderId: orderId.toString(),
        mode: mode,
        upiPackageId: upiPackageId,
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
    } catch (e, st) {
      debugPrint('Payment initiation error: $e');
      await ErrorTrackingService.captureException(
        e,
        stackTrace: st,
        tag: 'cashfree_initiate',
      );
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
