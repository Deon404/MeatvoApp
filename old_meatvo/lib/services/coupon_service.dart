import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

class CouponResult {
  const CouponResult({
    required this.isValid,
    this.discountAmount = 0,
    this.errorMessage,
    this.discountType,
    this.discountValue,
  });

  final bool isValid;
  final double discountAmount;
  final String? errorMessage;
  final String? discountType;
  final double? discountValue;
}

/// Coupon validation via POST /api/coupons/validate
class CouponService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  bool _isRequestSuccessful(dynamic data) {
    if (data is! Map) return false;
    final map = data.cast<String, dynamic>();
    return map['success'] == true || map['ok'] == true;
  }

  String _responseMessage(dynamic data, {String fallback = 'Coupon validation failed'}) {
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final error = map['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      final message = map['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback;
  }

  Map<String, dynamic>? _extractData(dynamic responseData) {
    if (responseData is Map) {
      final data = responseData['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    }
    return null;
  }

  Future<CouponResult> validateCoupon(String code, double orderAmount) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const CouponResult(
        isValid: false,
        errorMessage: 'Enter a coupon code',
      );
    }

    final user = await _storage.getUser();
    final body = <String, dynamic>{
      'code': trimmed,
      'orderAmount': orderAmount,
      if (user?.id != null && user!.id.isNotEmpty) 'userId': user.id,
    };

    try {
      final response = await _api.post(ApiCouponPaths.validate, data: body);
      final responseData = response.data;

      if (!_isRequestSuccessful(responseData)) {
        return CouponResult(
          isValid: false,
          errorMessage: _responseMessage(responseData),
        );
      }

      final data = _extractData(responseData);
      if (data == null || data['valid'] != true) {
        return CouponResult(
          isValid: false,
          errorMessage: _responseMessage(responseData, fallback: 'Invalid coupon'),
        );
      }

      final discountAmount = _toDouble(data['discountAmount']);
      return CouponResult(
        isValid: true,
        discountAmount: discountAmount,
        discountType: data['discountType']?.toString(),
        discountValue: data['discountValue'] != null
            ? _toDouble(data['discountValue'])
            : null,
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      return CouponResult(
        isValid: false,
        errorMessage: _responseMessage(
          responseData,
          fallback: e.message ?? 'Could not validate coupon',
        ),
      );
    } catch (e) {
      return CouponResult(
        isValid: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
