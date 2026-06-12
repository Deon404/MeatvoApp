import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache Service - Handles API response caching with TTL (Time To Live)
/// Uses Hive for persistent storage
class CacheService {
  static const String _boxName = 'api_cache';
  static Box? _box;
  static const Duration _defaultTTL = Duration(minutes: 5); // 5 minutes default cache

  /// Initialize cache service
  static Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  /// Get cached data by key
  static T? get<T>(String key) {
    if (_box == null || !_box!.isOpen) return null;

    try {
      final cachedData = _box!.get(key);
      if (cachedData == null) return null;

      final Map<String, dynamic> data = Map<String, dynamic>.from(cachedData as Map);
      final timestamp = DateTime.parse(data['timestamp'] as String);
      final ttl = Duration(seconds: data['ttl'] as int? ?? _defaultTTL.inSeconds);

      // Check if cache is expired
      if (DateTime.now().difference(timestamp) > ttl) {
        // Cache expired, remove it
        _box!.delete(key);
        return null;
      }

      // Return cached data
      return jsonDecode(data['data'] as String) as T;
    } catch (e) {
      // If error, remove corrupted cache
      _box!.delete(key);
      return null;
    }
  }

  /// Set cache data with optional TTL
  static Future<void> set(
    String key,
    dynamic data, {
    Duration? ttl,
  }) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }

    try {
      final cacheData = {
        'data': jsonEncode(data),
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': (ttl ?? _defaultTTL).inSeconds,
      };

      await _box!.put(key, cacheData);
    } catch (e) {
      // Silently fail - caching is not critical
    }
  }

  /// Remove specific cache entry
  static Future<void> remove(String key) async {
    if (_box == null || !_box!.isOpen) return;
    await _box!.delete(key);
  }

  /// Clear all cache
  static Future<void> clear() async {
    if (_box == null || !_box!.isOpen) return;
    await _box!.clear();
  }

  /// Clear expired cache entries
  static Future<void> clearExpired() async {
    if (_box == null || !_box!.isOpen) return;

    final keys = _box!.keys.toList();
    for (final key in keys) {
      try {
        final cachedData = _box!.get(key);
        if (cachedData == null) continue;

        final Map<String, dynamic> data = Map<String, dynamic>.from(cachedData as Map);
        final timestamp = DateTime.parse(data['timestamp'] as String);
        final ttl = Duration(seconds: data['ttl'] as int? ?? _defaultTTL.inSeconds);

        if (DateTime.now().difference(timestamp) > ttl) {
          await _box!.delete(key);
        }
      } catch (e) {
        // Remove corrupted cache
        await _box!.delete(key);
      }
    }
  }

  /// Clear cache entries by prefix
  static Future<void> clearByPrefix(String prefix) async {
    if (_box == null || !_box!.isOpen) {
      await init();
    }

    final keys = _box!.keys.toList();
    for (final key in keys) {
      final keyString = key.toString();
      if (keyString.startsWith(prefix)) {
        await _box!.delete(key);
      }
    }
  }

  /// Generate cache key from parameters
  static String generateKey(String baseKey, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) {
      return baseKey;
    }

    // Sort params for consistent keys
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final paramsString = sortedParams.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');

    return '$baseKey|$paramsString';
  }
}

