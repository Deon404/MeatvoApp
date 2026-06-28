import 'package:dio/dio.dart';

import 'api_service.dart';
import '../utils/store_time_util.dart';

enum StoreAcceptanceMode {
  accepting,
  limitedCapacity,
  notAccepting,
}

extension StoreAcceptanceModeX on StoreAcceptanceMode {
  String get apiValue {
    switch (this) {
      case StoreAcceptanceMode.accepting:
        return 'accepting';
      case StoreAcceptanceMode.limitedCapacity:
        return 'limited_capacity';
      case StoreAcceptanceMode.notAccepting:
        return 'not_accepting';
    }
  }

  String get customerLabel {
    switch (this) {
      case StoreAcceptanceMode.accepting:
        return 'Accepting Orders';
      case StoreAcceptanceMode.limitedCapacity:
        return 'Limited Capacity';
      case StoreAcceptanceMode.notAccepting:
        return 'Not Accepting Orders';
    }
  }

  static StoreAcceptanceMode fromApi(String? raw, {required bool isOpen}) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case 'limited_capacity':
      case 'busy':
        return StoreAcceptanceMode.limitedCapacity;
      case 'not_accepting':
      case 'closed':
        return StoreAcceptanceMode.notAccepting;
      case 'accepting':
      case 'open':
        return StoreAcceptanceMode.accepting;
      default:
        return isOpen
            ? StoreAcceptanceMode.accepting
            : StoreAcceptanceMode.notAccepting;
    }
  }
}

class StoreStatus {
  const StoreStatus({
    required this.isOpen,
    this.acceptanceMode = StoreAcceptanceMode.accepting,
    this.manualOpen = true,
    this.withinHours = true,
    this.storeOpenTime,
    this.storeCloseTime,
    this.closedReason,
    this.closedMessage,
    this.capacityMessage,
    this.nextOpenDisplay,
    this.deliveryRadiusKm = 8,
    this.minOrderAmount = 150,
    this.deliveryFee = 30,
    this.freeDeliveryThreshold = 500,
  });

  final bool isOpen;
  final StoreAcceptanceMode acceptanceMode;
  final bool manualOpen;
  final bool withinHours;
  final String? storeOpenTime;
  final String? storeCloseTime;
  final String? closedReason;
  final String? closedMessage;
  final String? capacityMessage;
  final String? nextOpenDisplay;
  final double deliveryRadiusKm;
  final double minOrderAmount;
  final double deliveryFee;
  final double freeDeliveryThreshold;

  bool get isAcceptingOrders =>
      acceptanceMode != StoreAcceptanceMode.notAccepting && isOpen;

  bool get isLimitedCapacity =>
      acceptanceMode == StoreAcceptanceMode.limitedCapacity && isOpen;

  String get displayStatusLabel => acceptanceMode.customerLabel;

  String get displayClosedMessage {
    if (closedMessage != null && closedMessage!.trim().isNotEmpty) {
      return closedMessage!.trim();
    }
    if (nextOpenDisplay != null && nextOpenDisplay!.trim().isNotEmpty) {
      return "We're not accepting orders right now. We'll resume from ${nextOpenDisplay!.trim()}.";
    }
    return "We're not accepting orders right now. Please check back soon.";
  }

  String? get displayCapacityMessage {
    if (!isLimitedCapacity) return null;
    if (capacityMessage != null && capacityMessage!.trim().isNotEmpty) {
      return capacityMessage!.trim();
    }
    return 'High demand right now — we are still accepting orders, but delivery may take a little longer.';
  }

  /// Store hours in 12-hour format, e.g. "8 AM – 11 PM".
  String? get displayStoreHours {
    final label = StoreTimeUtil.formatRange(storeOpenTime, storeCloseTime);
    return label.isEmpty ? null : label;
  }

  factory StoreStatus.fromJson(Map<String, dynamic> json) {
    final isOpen = json['isOpen'] == true || json['is_open'] == true;
    return StoreStatus(
      isOpen: isOpen,
      acceptanceMode: StoreAcceptanceModeX.fromApi(
        json['acceptanceMode']?.toString() ?? json['acceptance_mode']?.toString(),
        isOpen: isOpen,
      ),
      manualOpen: json['manualOpen'] == true ||
          json['manual_open'] == true ||
          json['store_open'] == true ||
          (json['manualOpen'] == null &&
              json['manual_open'] == null &&
              json['store_open'] == null),
      withinHours: json['withinHours'] == true ||
          json['within_hours'] == true ||
          (json['withinHours'] == null && json['within_hours'] == null),
      storeOpenTime: _stringOrNull(json['storeOpenTime'] ?? json['store_open_time']),
      storeCloseTime: _stringOrNull(json['storeCloseTime'] ?? json['store_close_time']),
      closedReason: _stringOrNull(json['closedReason'] ?? json['closed_reason']),
      closedMessage: _stringOrNull(json['closedMessage'] ?? json['closed_message']),
      capacityMessage: _stringOrNull(json['capacityMessage'] ?? json['capacity_message']),
      nextOpenDisplay:
          _stringOrNull(json['nextOpenDisplay'] ?? json['next_open_display']),
      deliveryRadiusKm: _toDouble(json['deliveryRadiusKm'] ?? json['delivery_radius_km']) ?? 8,
      minOrderAmount: _toDouble(json['minOrderAmount'] ?? json['min_order_amount']) ?? 150,
      deliveryFee: _toDouble(json['deliveryFee'] ?? json['delivery_fee']) ?? 30,
      freeDeliveryThreshold: (json['freeDeliveryThreshold'] as num?)
          ?.toDouble() ?? 500,
    );
  }


  static String? _stringOrNull(dynamic value) {

    if (value == null) return null;

    final text = value.toString().trim();

    return text.isEmpty ? null : text;

  }



  static double? _toDouble(dynamic value) {

    if (value == null) return null;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());

  }

}



class DeliveryEstimate {

  const DeliveryEstimate({

    required this.etaMinutes,

    required this.etaDisplay,

    this.estimatedTime,

    this.distanceKm,

  });



  final int etaMinutes;

  final String etaDisplay;

  final DateTime? estimatedTime;

  final double? distanceKm;



  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) {

    final rawTime = json['estimatedTime'] ?? json['estimated_time'];

    return DeliveryEstimate(

      etaMinutes: _toInt(json['etaMinutes'] ?? json['eta_minutes']) ?? 60,

      etaDisplay: (json['etaDisplay'] ?? json['eta_display'] ?? '').toString(),

      estimatedTime: rawTime != null ? DateTime.tryParse(rawTime.toString()) : null,

      distanceKm: StoreStatus._toDouble(json['distanceKm'] ?? json['distance_km']),

    );

  }



  static int? _toInt(dynamic value) {

    if (value == null) return null;

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value.toString());

  }



  String get checkoutLabel {

    if (etaDisplay.isNotEmpty) {

      if (etaDisplay.toLowerCase().startsWith('in ')) {

        return 'Express delivery · Arriving $etaDisplay';

      }

      if (etaDisplay.toLowerCase().startsWith('by ')) {

        return 'Express delivery · $etaDisplay';

      }

      return 'Express delivery · $etaDisplay';

    }

    return 'Express delivery · within 1 hour';

  }

}



/// Backend-driven store status and express delivery ETA preview.

class StoreStatusService {

  StoreStatusService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static StoreStatus? _cachedStatus;
  static DateTime? _cachedAt;
  static const _cacheTtl = Duration(minutes: 2);
  static const _fetchTimeout = Duration(seconds: 12);



  dynamic _extractData(dynamic responseData) {

    if (responseData is Map<String, dynamic>) {

      if (responseData['data'] is Map<String, dynamic>) {

        return responseData['data'];

      }

      return responseData;

    }

    return responseData;

  }



  Future<StoreStatus> fetchStatus({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedStatus != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _cachedStatus!;
    }

    try {
      final res = await _api.get(
        '/store/status',
        options: Options(
          receiveTimeout: _fetchTimeout,
          sendTimeout: _fetchTimeout,
        ),
      );
      final data = _extractData(res.data);
      if (data is Map<String, dynamic>) {
        final status = StoreStatus.fromJson(data);
        _cachedStatus = status;
        _cachedAt = DateTime.now();
        return status;
      }
      return const StoreStatus(isOpen: true);
    } on DioException catch (e) {
      if (_cachedStatus != null) return _cachedStatus!;
      if (_isTimeout(e)) return const StoreStatus(isOpen: true);
      throw Exception(
        e.response?.data?['message']?.toString() ?? 'Could not load store status',
      );
    }
  }

  static bool _isTimeout(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }



  Future<DeliveryEstimate> estimateDelivery({

    required double lat,

    required double lng,

    List<num>? itemQuantities,

  }) async {

    try {

      final res = await _api.post(

        '/store/estimate-delivery',

        data: {

          'lat': lat,

          'lng': lng,

          if (itemQuantities != null && itemQuantities.isNotEmpty)

            'items': itemQuantities.map((q) => {'quantity': q.round()}).toList(),

        },

      );

      final data = _extractData(res.data);

      if (data is Map<String, dynamic>) {

        return DeliveryEstimate.fromJson(data);

      }

      throw Exception('Invalid delivery estimate response');

    } on DioException catch (e) {

      final message = e.response?.data?['message']?.toString();

      throw Exception(message ?? 'Could not estimate delivery time');

    }

  }



  Future<StoreStatus> toggleStoreOpen() async {
    try {
      final res = await _api.patch('/admin/store/toggle');
      final data = _extractData(res.data);
      if (data is Map<String, dynamic>) {
        return StoreStatus.fromJson(data);
      }
      return const StoreStatus(
        isOpen: false,
        acceptanceMode: StoreAcceptanceMode.notAccepting,
        manualOpen: false,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message']?.toString() ?? 'Could not update store status',
      );
    }
  }

  Future<StoreStatus> setAcceptanceMode(StoreAcceptanceMode mode) async {
    try {
      final res = await _api.patch(
        '/admin/store/acceptance-mode',
        data: {'mode': mode.apiValue},
      );
      final data = _extractData(res.data);
      if (data is Map<String, dynamic>) {
        return StoreStatus.fromJson(data);
      }
      throw Exception('Invalid store status response');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message']?.toString() ?? 'Could not update store status',
      );
    }
  }
}

