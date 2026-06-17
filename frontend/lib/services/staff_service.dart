import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import 'api_service.dart';

final staffServiceProvider = Provider<StaffService>((ref) {
  return StaffService(ref);
});

class StaffService {
  StaffService(this._ref);

  final Ref _ref;

  ApiService get _api => _ref.read(apiServiceProvider);

  Future<List<Map<String, dynamic>>> getKitchenOrders({
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null && status.isNotEmpty) {
        query['status'] = _mapStatusToBackend(status);
      }

      final res = await _api.get(ApiStaffPaths.orders, queryParameters: query);
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to load kitchen orders');
      }

      final data = res.data['data'];
      final rawOrders = data is Map
          ? (data['orders'] as List<dynamic>? ?? const [])
          : (data as List<dynamic>? ?? const []);

      return rawOrders
          .whereType<Map>()
          .map((order) => normalizeKitchenOrder(Map<String, dynamic>.from(order)))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? e.message ?? 'Failed to load kitchen orders',
      );
    }
  }

  Future<void> startPreparing(String orderId) async {
    await _postPackingAction(
      ApiStaffPaths.startPacking(orderId),
      'Failed to start preparing',
    );
  }

  Future<void> markReady(String orderId) async {
    await _postPackingAction(
      ApiStaffPaths.markPacked(orderId),
      'Failed to mark order ready',
    );
  }

  Future<void> _postPackingAction(String path, String fallbackMessage) async {
    try {
      final res = await _api.post(path);
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? fallbackMessage);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? e.message ?? fallbackMessage);
    }
  }

  String _mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'confirmed':
      case 'accepted':
        return 'CONFIRMED';
      case 'preparing':
      case 'packing_started':
        return 'PACKING_STARTED';
      default:
        return status.toUpperCase();
    }
  }

  Map<String, dynamic> normalizeKitchenOrder(Map<String, dynamic> raw) {
    final itemsRaw = raw['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((item) => {
                  'id': (item['id'] ?? '').toString(),
                  'name': (item['name'] ?? 'Item').toString(),
                  'quantity': num.tryParse(item['quantity']?.toString() ?? '') ??
                      (item['quantity'] as num?)?.toDouble() ??
                      0,
                  'price': num.tryParse(item['price']?.toString() ?? '') ??
                      (item['price'] as num?)?.toDouble() ??
                      0,
                })
            .toList()
        : <Map<String, dynamic>>[];

    final slotRaw = raw['deliverySlot'] ?? raw['delivery_slot'];
    String? slotLabel;
    if (slotRaw is Map) {
      final name = slotRaw['name']?.toString();
      final start = slotRaw['startTime'] ?? slotRaw['start_time'];
      final end = slotRaw['endTime'] ?? slotRaw['end_time'];
      if (name != null && name.isNotEmpty) {
        slotLabel = name;
      } else if (start != null || end != null) {
        slotLabel = '${start ?? ''} - ${end ?? ''}'.trim();
      }
    }

    return {
      'id': (raw['id'] ?? '').toString(),
      'status': _normalizeStatusForUi(raw['status']),
      'totalAmount': num.tryParse(raw['totalAmount']?.toString() ?? '') ??
          (raw['totalAmount'] as num?)?.toDouble() ??
          0,
      'createdAt': raw['createdAt'] ?? raw['created_at'],
      'createdAtMs': num.tryParse(raw['createdAtMs']?.toString() ?? '')?.toInt() ??
          (raw['createdAtMs'] as int?),
      'deliverySlot': slotLabel,
      'items': items,
    };
  }

  String _normalizeStatusForUi(dynamic status) {
    final normalized = (status ?? '').toString().toLowerCase();
    switch (normalized) {
      case 'confirmed':
        return 'confirmed';
      case 'packing_started':
        return 'packing_started';
      default:
        return normalized;
    }
  }
}
