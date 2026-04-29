import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address_model.dart';
import '../providers/cart_provider.dart';
import 'api_service.dart';

final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return CheckoutService(ref);
});

class CheckoutService {
  final Ref _ref;
  CheckoutService(this._ref);

  Future<List<AddressModel>> getAddresses() async {
    final response = await _ref.read(apiServiceProvider).get('/v1/addresses');
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final list = (data['addresses'] ?? const <dynamic>[]) as List<dynamic>;
    return list.map((e) => AddressModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AddressModel> addAddress({
    required String label,
    required String addressLine,
    String landmark = '',
    double lat = 0,
    double lng = 0,
    bool isDefault = false,
  }) async {
    final response = await _ref.read(apiServiceProvider).post(
      '/v1/addresses',
      data: {
        'label': label,
        'addressLine': addressLine,
        'landmark': landmark,
        'lat': lat,
        'lng': lng,
        'isDefault': isDefault,
      },
    );
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    return AddressModel.fromJson((data['address'] ?? data) as Map<String, dynamic>);
  }

  Future<CouponResult> applyCoupon({
    required String code,
    required double orderTotal,
  }) async {
    final response = await _ref.read(apiServiceProvider).post(
      '/v1/orders/apply-coupon',
      data: {
        'code': code,
        'orderTotal': orderTotal,
      },
    );
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    return CouponResult(
      discount: ((data['discount'] ?? 0) as num).toDouble(),
      finalTotal: ((data['finalTotal'] ?? orderTotal) as num).toDouble(),
      message: (data['message'] ?? 'Coupon applied').toString(),
    );
  }

  Future<PlaceOrderResult> placeOrder({
    required int addressId,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final cartItems = _ref.read(cartProvider);
    final response = await _ref.read(apiServiceProvider).post(
      '/v1/orders',
      data: {
        'items': cartItems
            .map(
              (e) => {
                'productId': e.product.id,
                'quantity': e.quantity,
              },
            )
            .toList(),
        'deliveryAddressId': addressId,
        'paymentMethod': paymentMethod,
        if (couponCode != null && couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim(),
      },
    );

    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final order = (data['order'] ?? data) as Map<String, dynamic>;
    return PlaceOrderResult(
      orderId: (order['id'] ?? '').toString(),
      status: (order['status'] ?? 'PENDING').toString(),
    );
  }

  Future<String?> initiatePayment(String orderId) async {
    final response = await _ref.read(apiServiceProvider).post(
      '/v1/payments/initiate',
      data: {'orderId': orderId},
    );
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    return (data['checkoutUrl'] ?? data['paymentUrl'])?.toString();
  }
}

class CouponResult {
  final double discount;
  final double finalTotal;
  final String message;

  const CouponResult({
    required this.discount,
    required this.finalTotal,
    required this.message,
  });
}

class PlaceOrderResult {
  final String orderId;
  final String status;

  const PlaceOrderResult({
    required this.orderId,
    required this.status,
  });
}
