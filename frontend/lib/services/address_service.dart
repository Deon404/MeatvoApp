import 'package:dio/dio.dart';
import '../config/backend_resolver.dart';
import '../models/address_model.dart';
import 'api_service.dart';

/// Address service — custom Node.js backend
class AddressService {
  final ApiService _api = ApiService();

  // ── Helpers ───────────────────────────────────────────────────────────────

  AddressModel _parse(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    // Normalize camelCase → snake_case for AddressModel.fromJson
    m['address_line1'] ??= m['addressLine1'] ?? m['address_line'];
    m['latitude'] ??= m['lat'];
    m['longitude'] ??= m['lng'];
    m['address_line2'] ??= m['addressLine2'];
    m['is_default'] ??= m['isDefault'] ?? false;
    m['created_at'] ??= m['createdAt'];
    m['updated_at'] ??= m['updatedAt'];
    m['user_id'] ??= m['userId'];
    if (m['label'] == null && m['address_type'] != null) {
      m['label'] = (m['address_type'] as String).toLowerCase();
    }
    return AddressModel.fromJson(m);
  }

  Map<String, dynamic> _parseResponseData(dynamic data) {
    if (data is! Map) return {};
    final map = Map<String, dynamic>.from(data);
    if (map['address'] is Map) {
      return Map<String, dynamic>.from(map['address'] as Map);
    }
    return map;
  }

  String _extractErrorMessage(DioException e, String fallback) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      final detail = e.error?.toString().trim();
      if (detail != null &&
          detail.isNotEmpty &&
          detail.contains(BackendResolver.connectionErrorPrefix)) {
        return detail;
      }
      return BackendResolver.connectionUserMessage();
    }

    final data = e.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final error = map['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      final message = map['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Get all addresses for the current user.
  Future<List<AddressModel>> getUserAddresses({String? userId}) async {
    try {
      final res = await _api.get('/addresses');
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to fetch addresses');
      }
      final body = res.data as Map<String, dynamic>;

      // Backend: { success, data: { addresses: [...] } } or data: [...]
      dynamic raw = body['data'] ?? body['addresses'] ?? [];
      if (raw is Map<String, dynamic>) {
        raw = raw['addresses'] ?? raw['address'] ?? [];
      }
      if (raw is List) {
        return raw
            .map((e) => _parse(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
          'Failed to fetch addresses: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to fetch addresses: $e');
    }
  }

  /// Get the default address (first address marked isDefault, or first in list).
  Future<AddressModel?> getDefaultAddress({String? userId}) async {
    try {
      final addresses = await getUserAddresses(userId: userId);
      if (addresses.isEmpty) return null;
      return addresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => addresses.first,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get address by ID from local list (no dedicated backend endpoint).
  Future<AddressModel?> getAddressById(String addressId) async {
    try {
      final addresses = await getUserAddresses();
      return addresses.firstWhere(
        (a) => a.id == addressId,
        orElse: () => throw StateError('Not found'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Add a new address.
  Future<AddressModel> addAddress(AddressModel address) async {
    try {
      final body = <String, dynamic>{
        'label': address.label.name,
        'addressLine1': address.addressLine1,
        'city': address.city,
        'state': address.state,
        'pincode': address.pincode,
        'lat': address.latitude,
        'lng': address.longitude,
        if (address.addressLine2 != null && address.addressLine2!.isNotEmpty)
          'addressLine2': address.addressLine2,
        if (address.landmark != null && address.landmark!.isNotEmpty)
          'landmark': address.landmark,
        'isDefault': address.isDefault,
      };

      final res = await _api.post('/addresses', data: body);
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to add address');
      }
      return _parse(_parseResponseData(res.data['data']));
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Request failed');
      throw Exception('Failed to add address: $msg');
    } catch (e) {
      throw Exception('Failed to add address: $e');
    }
  }

  /// Update an existing address.
  Future<AddressModel> updateAddress(AddressModel address) async {
    try {
      final body = <String, dynamic>{
        'label': address.label.name,
        'addressLine1': address.addressLine1,
        'city': address.city,
        'state': address.state,
        'pincode': address.pincode,
        'lat': address.latitude,
        'lng': address.longitude,
        if (address.addressLine2 != null) 'addressLine2': address.addressLine2,
        if (address.landmark != null) 'landmark': address.landmark,
        'isDefault': address.isDefault,
      };

      final res = await _api.patch('/addresses/${address.id}', data: body);
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to update address');
      }
      return _parse(_parseResponseData(res.data['data']));
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Request failed');
      throw Exception('Failed to update address: $msg');
    } catch (e) {
      throw Exception('Failed to update address: $e');
    }
  }

  /// Delete an address.
  Future<void> deleteAddress(String addressId) async {
    try {
      final res = await _api.delete('/addresses/$addressId');
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to delete address');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to delete address: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to delete address: $e');
    }
  }

  /// Set an address as the default.
  Future<AddressModel> setDefaultAddress(String addressId) async {
    try {
      final res = await _api.patch(
        '/addresses/$addressId',
        data: {'isDefault': true},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to set default address');
      }
      return _parse(_parseResponseData(res.data['data']));
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Request failed');
      throw Exception('Failed to set default address: $msg');
    } catch (e) {
      throw Exception('Failed to set default address: $e');
    }
  }
}
