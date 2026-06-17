import 'package:dio/dio.dart';

import 'api_service.dart';

class AppInfo {
  const AppInfo({required this.appVersion});

  final String appVersion;

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['appVersion'] ?? json['app_version'];
    final version = raw?.toString().trim();
    return AppInfo(appVersion: version?.isNotEmpty == true ? version! : '1.0.0');
  }

  static const fallback = AppInfo(appVersion: '1.0.0');
}

/// Fetches public app metadata (version label) from backend app_settings.
class AppInfoService {
  AppInfoService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  AppInfo? _cache;

  Future<AppInfo> fetchAppInfo({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    try {
      final res = await _api.get('/settings/app-info');
      final data = _extractData(res.data);
      if (data is Map<String, dynamic>) {
        _cache = AppInfo.fromJson(data);
        return _cache!;
      }
    } on DioException {
      // Fall through to cached/default.
    }

    _cache ??= AppInfo.fallback;
    return _cache!;
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData['data'] is Map<String, dynamic>) {
        return responseData['data'];
      }
      return responseData;
    }
    return responseData;
  }
}
