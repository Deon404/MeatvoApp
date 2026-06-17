import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/banner_model.dart';
import '../utils/media_url_resolver.dart';
import 'api_service.dart';
import 'cache_service.dart';

/// Banner service — custom Node.js backend (GET /api/banners)
class BannerService {
  final ApiService _api = ApiService();

  List<dynamic> _extractBannerList(dynamic responseData) {
    if (responseData is! Map || responseData['success'] != true) {
      return const [];
    }

    final data = responseData['data'];
    if (data is Map && data['banners'] is List) {
      return data['banners'] as List;
    }
    if (data is List) {
      return data;
    }
    return const [];
  }

  Map<String, dynamic> _normalizeBannerJson(Map<String, dynamic> json) {
    return <String, dynamic>{
      'id': (json['id'] ?? '').toString(),
      'title': (json['title'] ?? 'Fresh offer').toString(),
      'subtitle': json['subtitle']?.toString(),
      'image_url': MediaUrlResolver.resolve(
        (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      ) ?? '',
      'link': json['link']?.toString(),
      'link_type': json['link_type']?.toString(),
      'link_id': json['link_id']?.toString(),
      'display_order': json['display_order'] ?? json['sort_order'] ?? 0,
      'is_active': json['is_active'] ?? json['active'] ?? true,
      'start_date': json['start_date'],
      'end_date': json['end_date'],
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
    };
  }

  List<BannerModel> _parseBanners(List<dynamic> rawList) {
    return rawList
        .map((e) => _normalizeBannerJson(Map<String, dynamic>.from(e as Map)))
        .where((json) => (json['image_url'] as String).trim().isNotEmpty)
        .map(BannerModel.fromJson)
        .where((banner) => banner.isValid)
        .toList();
  }

  Future<List<BannerModel>> getActiveBanners({
    bool useCache = true,
  }) async {
    const cacheKey = 'active_banners';

    if (useCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return _parseBanners(cached);
        } catch (_) {
          await CacheService.remove(cacheKey);
        }
      }
    }

    try {
      final res = await _api.get('/banners');
      final rawList = _extractBannerList(res.data);
      if (rawList.isEmpty) {
        debugPrint('⚠️ Banner API returned success=false');
        return [];
      }
      final validBanners = _parseBanners(rawList);

      if (useCache) {
        await CacheService.set(
          cacheKey,
          rawList,
          ttl: const Duration(minutes: 2),
        );
      }

      return validBanners;
    } on DioException catch (e) {
      debugPrint('⚠️ Network error fetching banners: ${e.message}');

      // Return cached data even if expired
      if (useCache) {
        final cached = CacheService.get<List<dynamic>>(cacheKey);
        if (cached != null) {
          try {
            return _parseBanners(cached);
          } catch (_) {}
        }
      }
      return [];
    } catch (e) {
      debugPrint('⚠️ Error fetching banners: $e');
      return [];
    }
  }

  Future<List<BannerModel>> getAllBanners() async {
    try {
      final res = await _api.get('/banners');
      return _parseBanners(_extractBannerList(res.data));
    } catch (e) {
      debugPrint('⚠️ Error fetching all banners: $e');
      return [];
    }
  }

  static Future<void> clearBannerCache() async {
    await CacheService.remove('active_banners');
  }

  Future<BannerModel?> getBannerById(String bannerId) async {
    try {
      final banners = await getAllBanners();
      return banners.firstWhere(
        (b) => b.id == bannerId,
        orElse: () => throw StateError('Not found'),
      );
    } catch (_) {
      return null;
    }
  }
}
