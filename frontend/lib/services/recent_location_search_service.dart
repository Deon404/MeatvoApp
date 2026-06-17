import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists recent locality search picks (Zappfresh-style).
class RecentLocationSearchService {
  static const _key = 'recent_location_searches';
  static const _maxItems = 5;

  Future<List<Map<String, dynamic>>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['latitude'] != null && e['longitude'] != null)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPlace(Map<String, dynamic> place) async {
    final lat = (place['latitude'] as num?)?.toDouble();
    final lng = (place['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final title = (place['primary_text'] as String?) ??
        (place['description'] as String?) ??
        (place['formatted_address'] as String?) ??
        'Selected location';
    final subtitle = (place['secondary_text'] as String?) ?? '';

    final entry = <String, dynamic>{
      'latitude': lat,
      'longitude': lng,
      'primary_text': title,
      'secondary_text': subtitle,
      'place_id': place['place_id'],
    };

    final existing = await getRecent();
    final filtered = existing.where((e) {
      final eLat = (e['latitude'] as num?)?.toDouble();
      final eLng = (e['longitude'] as num?)?.toDouble();
      return eLat != lat || eLng != lng;
    }).toList();

    filtered.insert(0, entry);
    if (filtered.length > _maxItems) {
      filtered.removeRange(_maxItems, filtered.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(filtered));
  }
}
