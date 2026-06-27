import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  const AppInfo({required this.appVersion});

  final String appVersion;

  factory AppInfo.fromPackageInfo(PackageInfo info) {
    final build = info.buildNumber.trim();
    final version = build.isNotEmpty ? '${info.version}+$build' : info.version;
    return AppInfo(appVersion: version);
  }
}

/// Reads app version from pubspec.yaml (via platform package metadata).
class AppInfoService {
  AppInfo? _cache;

  Future<AppInfo> fetchAppInfo({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    final info = await PackageInfo.fromPlatform();
    _cache = AppInfo.fromPackageInfo(info);
    return _cache!;
  }
}
