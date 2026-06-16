import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/delivery_slot_model.dart';
import 'api_service.dart';

/// Fetches real delivery slots from backend and supports booking.
class DeliverySlotApiService {
  final ApiService _api = ApiService();

  bool _isSuccess(dynamic data) {
    if (data is! Map) return false;
    return data['success'] == true || data['ok'] == true;
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map) return responseData['data'];
    return null;
  }

  List<DeliverySlotModel> _parseSlots(dynamic data) {
    if (data is! Map) return const [];
    final slots = data['slots'];
    if (slots is! List) return const [];
    return slots
        .whereType<Map>()
        .map((e) => DeliverySlotModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /delivery/slots?date=YYYY-MM-DD
  Future<List<DeliverySlotModel>> fetchSlots({DateTime? date}) async {
    try {
      final query = date != null
          ? {'date': DeliverySlotModel.formatDateKey(date)}
          : null;

      final res = await _api.get(
        ApiDeliveryPaths.slots,
        queryParameters: query,
      );

      if (!_isSuccess(res.data)) {
        throw Exception(
          res.data is Map ? (res.data['message'] ?? 'Failed to load slots') : 'Failed to load slots',
        );
      }

      return _parseSlots(_extractData(res.data));
    } on DioException catch (e) {
      throw Exception(
        e.response?.data is Map
            ? (e.response?.data['message'] ?? e.message)
            : e.message,
      );
    }
  }

  /// GET /delivery/slots/:id
  Future<DeliverySlotModel> getSlotById(int id) async {
    try {
      final res = await _api.get('${ApiDeliveryPaths.slots}/$id');
      if (!_isSuccess(res.data)) {
        throw Exception(res.data is Map ? (res.data['message'] ?? 'Slot not found') : 'Slot not found');
      }
      final data = _extractData(res.data);
      if (data is Map && data['slot'] is Map) {
        return DeliverySlotModel.fromJson(
          Map<String, dynamic>.from(data['slot'] as Map),
        );
      }
      throw Exception('Slot not found');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data is Map
            ? (e.response?.data['message'] ?? e.message)
            : e.message,
      );
    }
  }

  /// POST /delivery/slots/:id/book
  Future<DeliverySlotModel> bookSlot(int id, {int quantity = 1}) async {
    try {
      final res = await _api.post(
        '${ApiDeliveryPaths.slots}/$id/book',
        data: {'quantity': quantity},
      );
      if (!_isSuccess(res.data)) {
        throw Exception(res.data is Map ? (res.data['message'] ?? 'Failed to book slot') : 'Failed to book slot');
      }
      final data = _extractData(res.data);
      if (data is Map && data['slot'] is Map) {
        return DeliverySlotModel.fromJson(
          Map<String, dynamic>.from(data['slot'] as Map),
        );
      }
      return getSlotById(id);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data is Map
            ? (e.response?.data['message'] ?? e.message)
            : e.message,
      );
    }
  }

  /// Available dates for checkout (today + next 6 days).
  static List<DateTime> availableDates({int days = 7}) {
    final now = DateTime.now();
    return List.generate(
      days,
      (i) => DateTime(now.year, now.month, now.day + i),
    );
  }

  static String formatDateLabel(DateTime date) =>
      DeliverySlotModel.formatDateLabel(date);
}
