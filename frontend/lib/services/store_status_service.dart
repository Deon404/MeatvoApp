import 'package:dio/dio.dart';



import 'api_service.dart';
import '../utils/store_time_util.dart';

class StoreStatus {

  const StoreStatus({

    required this.isOpen,

    this.manualOpen = true,

    this.withinHours = true,

    this.storeOpenTime,

    this.storeCloseTime,

    this.closedReason,

    this.closedMessage,

    this.nextOpenDisplay,

    this.deliveryRadiusKm = 8,

    this.minOrderAmount = 150,

    this.deliveryFee = 30,

  });



  final bool isOpen;

  final bool manualOpen;

  final bool withinHours;

  final String? storeOpenTime;

  final String? storeCloseTime;

  final String? closedReason;

  final String? closedMessage;

  final String? nextOpenDisplay;

  final double deliveryRadiusKm;

  final double minOrderAmount;

  final double deliveryFee;



  String get displayClosedMessage {

    if (closedMessage != null && closedMessage!.trim().isNotEmpty) {

      return closedMessage!.trim();

    }

    if (nextOpenDisplay != null && nextOpenDisplay!.trim().isNotEmpty) {

      return "Store is closed right now. We'll take orders from ${nextOpenDisplay!.trim()}.";

    }

    return "Store is closed right now. We'll take orders when we're open again.";
  }

  /// Store hours in 12-hour format, e.g. "8 AM – 11 PM".
  String? get displayStoreHours {
    final label = StoreTimeUtil.formatRange(storeOpenTime, storeCloseTime);
    return label.isEmpty ? null : label;
  }

  factory StoreStatus.fromJson(Map<String, dynamic> json) {

    return StoreStatus(

      isOpen: json['isOpen'] == true || json['is_open'] == true,

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

      nextOpenDisplay:

          _stringOrNull(json['nextOpenDisplay'] ?? json['next_open_display']),

      deliveryRadiusKm: _toDouble(json['deliveryRadiusKm'] ?? json['delivery_radius_km']) ?? 8,

      minOrderAmount: _toDouble(json['minOrderAmount'] ?? json['min_order_amount']) ?? 150,

      deliveryFee: _toDouble(json['deliveryFee'] ?? json['delivery_fee']) ?? 30,

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



  dynamic _extractData(dynamic responseData) {

    if (responseData is Map<String, dynamic>) {

      if (responseData['data'] is Map<String, dynamic>) {

        return responseData['data'];

      }

      return responseData;

    }

    return responseData;

  }



  Future<StoreStatus> fetchStatus() async {

    try {

      final res = await _api.get('/store/status');

      final data = _extractData(res.data);

      if (data is Map<String, dynamic>) {

        return StoreStatus.fromJson(data);

      }

      return const StoreStatus(isOpen: true);

    } on DioException catch (e) {

      throw Exception(

        e.response?.data?['message']?.toString() ?? 'Could not load store status',

      );

    }

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

      return const StoreStatus(isOpen: false, manualOpen: false);

    } on DioException catch (e) {

      throw Exception(

        e.response?.data?['message']?.toString() ?? 'Could not toggle store status',

      );

    }

  }

}

