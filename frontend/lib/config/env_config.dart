// Keys must match shared/env-manifest.json — do not add keys here
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Runtime configuration: non-sensitive values from `.env`, JWT/session data via
/// [StorageService] + [FlutterSecureStorage].
///
/// Call [load] in `main()` before any service reads keys or API paths.
class EnvConfig {
  EnvConfig._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Meta-key: optional override for a secret stored only on-device (not in `.env`).
  static String _secureOverrideKey(String envKey) => 'env_override_$envKey';

  static bool _loaded = false;
  static final Map<String, String> _dartDefines = {};

  static Map<String, String> get _env {
    if (!dotenv.isInitialized) {
      return Map<String, String>.from(_dartDefines);
    }
    return {...dotenv.env, ..._dartDefines};
  }

  static void _loadDartDefines() {
    void put(String key, String value) {
      if (value.isNotEmpty) _dartDefines[key] = value;
    }

    put('API_BASE_URL', const String.fromEnvironment('API_BASE_URL'));
    put('MEATVO_API_ROOT', const String.fromEnvironment('MEATVO_API_ROOT'));
    put('BACKEND_ROOT_URL', const String.fromEnvironment('BACKEND_ROOT_URL'));
    put('API_URL', const String.fromEnvironment('API_URL'));
    put('APP_ENV', const String.fromEnvironment('APP_ENV'));
    put('CASHFREE_ENV', const String.fromEnvironment('CASHFREE_ENV'));
    put('GOOGLE_MAPS_API_KEY', const String.fromEnvironment('GOOGLE_MAPS_API_KEY'));
    put('FIREBASE_API_KEY', const String.fromEnvironment('FIREBASE_API_KEY'));
    put('FIREBASE_PROJECT_ID', const String.fromEnvironment('FIREBASE_PROJECT_ID'));
    put(
      'FIREBASE_MESSAGING_SENDER_ID',
      const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    );
    put('FIREBASE_APP_ID', const String.fromEnvironment('FIREBASE_APP_ID'));
    put(
      'FIREBASE_STORAGE_BUCKET',
      const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
    put('SENTRY_DSN', const String.fromEnvironment('SENTRY_DSN'));
    put('API_AUTH_SEND_OTP_PATH', const String.fromEnvironment('API_AUTH_SEND_OTP_PATH'));
    put('API_AUTH_VERIFY_OTP_PATH', const String.fromEnvironment('API_AUTH_VERIFY_OTP_PATH'));
    put('API_AUTH_REFRESH_PATH', const String.fromEnvironment('API_AUTH_REFRESH_PATH'));
    put(
      'API_AUTH_REFRESH_TOKEN_PATH',
      const String.fromEnvironment('API_AUTH_REFRESH_TOKEN_PATH'),
    );
  }

  /// Read any non-sensitive key from dart-define, then `.env` / defaults.
  ///
  /// Example: `EnvConfig.get('API_BASE_URL')`
  static String get(String key, {String defaultValue = ''}) {
    final dartValue = _dartDefines[key]?.trim();
    if (dartValue != null && dartValue.isNotEmpty) {
      return dartValue;
    }
    final value = dotenv.isInitialized ? dotenv.env[key]?.trim() : null;
    if (value == null || value.isEmpty) {
      return defaultValue;
    }
    return value;
  }

  /// Like [get] but throws if the value is missing or empty.
  static String require(String key) {
    final value = get(key);
    if (value.isEmpty) {
      throw StateError('Missing required env key: $key');
    }
    return value;
  }

  static String _envOrDefault(String key, String fallback) {
    final value = get(key);
    if (value.isEmpty) {
      return fallback;
    }
    return value;
  }

  // ── Backend API root ──────────────────────────────────────────────────────

  /// Primary backend URL (no trailing slash). Supports legacy env names.
  static String get apiBaseUrl {
    for (final key in [
      'API_BASE_URL',
      'MEATVO_API_ROOT',
      'BACKEND_ROOT_URL',
      'API_URL',
    ]) {
      final normalized = normalizeBackendRoot(get(key));
      if (normalized != null) {
        return normalized;
      }
    }
    return backendRootUrl;
  }

  // ── Supabase (optional — realtime / legacy docs) ──────────────────────────

  static String get supabaseUrl => get('SUPABASE_URL');

  static String get supabaseAnonKey => get('SUPABASE_ANON_KEY');

  // ── Secure storage key names (identifiers only — not JWT values) ───────────

  static String get secureStorageAccessTokenKey => _envOrDefault(
        'SECURE_STORAGE_ACCESS_TOKEN_KEY',
        'access_token',
      );

  static String get secureStorageRefreshTokenKey => _envOrDefault(
        'SECURE_STORAGE_REFRESH_TOKEN_KEY',
        'refresh_token',
      );

  static String get secureStorageUserDataKey => _envOrDefault(
        'SECURE_STORAGE_USER_DATA_KEY',
        'user_data',
      );

  static String get secureStorageUserRoleKey => _envOrDefault(
        'SECURE_STORAGE_USER_ROLE_KEY',
        'user_role',
      );

  static String get secureStorageUserIdKey => _envOrDefault(
        'SECURE_STORAGE_USER_ID_KEY',
        'user_id',
      );

  // ── Auth API paths (backend contract — configurable in `.env`) ────────────

  static String get apiAuthRefreshPath =>
      _envOrDefault('API_AUTH_REFRESH_PATH', '/auth/refresh');

  static String get apiAuthRefreshTokenPath => _envOrDefault(
        'API_AUTH_REFRESH_TOKEN_PATH',
        '/auth/refresh-token',
      );

  static String get apiAuthSendOtpPath =>
      _envOrDefault('API_AUTH_SEND_OTP_PATH', '/auth/send-otp');

  static String get apiAuthVerifyOtpPath =>
      _envOrDefault('API_AUTH_VERIFY_OTP_PATH', '/auth/verify-otp');

  // ── Google Maps ───────────────────────────────────────────────────────────

  static String get googleMapsApiKey => get('GOOGLE_MAPS_API_KEY');

  static bool get hasGoogleMapsApiKey {
    final key = googleMapsApiKey;
    if (key.isEmpty || key.length < 20) return false;
    final lower = key.toLowerCase();
    return !lower.contains('your-google-maps') &&
        !lower.contains('your_key') &&
        !lower.contains('your_api');
  }

  static String get merchantPhoneNumber => get('MERCHANT_PHONE_NUMBER');

  /// Cashfree SDK environment: `production` | `sandbox` | empty (falls back to APP_ENV).
  static String get cashfreeEnv => get('CASHFREE_ENV', defaultValue: '');

  static bool get cashfreeUseProduction {
    final env = cashfreeEnv.trim().toLowerCase();
    if (env == 'production' || env == 'prod') return true;
    if (env == 'sandbox' || env == 'test') return false;
    return isProduction;
  }

  // ── Firebase ──────────────────────────────────────────────────────────────

  static String get firebaseApiKey => get('FIREBASE_API_KEY');

  static String get firebaseProjectId => get('FIREBASE_PROJECT_ID');

  static String get firebaseMessagingSenderId =>
      get('FIREBASE_MESSAGING_SENDER_ID');

  static String get firebaseAppId => get('FIREBASE_APP_ID');

  static String get firebaseStorageBucket => get('FIREBASE_STORAGE_BUCKET');

  // ── Sentry ────────────────────────────────────────────────────────────────

  static String get sentryDsn => get('SENTRY_DSN');

  static double get sentryTracesSampleRate =>
      double.tryParse(get('SENTRY_TRACES_SAMPLE_RATE', defaultValue: '1.0')) ??
      1.0;

  // ── App environment ───────────────────────────────────────────────────────

  static String get appEnv => get('APP_ENV', defaultValue: 'development');

  static bool get isDevelopment => appEnv == 'development';

  static bool get isProduction => appEnv == 'production';

  static const int defaultBackendPort = 8080;

  static String? get configuredBackendRoot {
    for (final key in [
      'API_BASE_URL',
      'MEATVO_API_ROOT',
      'BACKEND_ROOT_URL',
      'API_URL',
    ]) {
      final normalized = normalizeBackendRoot(get(key));
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  static String get backendRootUrl {
    final configuredRoot = configuredBackendRoot;
    if (configuredRoot != null) {
      return configuredRoot;
    }

    if (isProduction) {
      throw StateError(
        'Missing API_BASE_URL for production. Pass --dart-define-from-file=env.production.json',
      );
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:$defaultBackendPort';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:$defaultBackendPort';
      default:
        return 'http://127.0.0.1:$defaultBackendPort';
    }
  }

  static String? normalizeBackendRoot(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    var normalized = value;
    if (!normalized.contains('://')) {
      normalized = 'http://$normalized';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    // Only default port 8080 for plain HTTP; HTTPS keeps implicit 443.
    final needsDefaultPort =
        !uri.hasPort && uri.scheme.toLowerCase() == 'http';
    final resolved =
        needsDefaultPort ? uri.replace(port: defaultBackendPort) : uri;
    return resolved.toString().replaceFirst(RegExp(r'/$'), '');
  }

  /// Loads defaults from assets and merges `--dart-define` / `--dart-define-from-file`.
  /// Production builds must pass API_BASE_URL via dart-define (secrets are not bundled).
  static Future<void> load({
    bool persistSecretsToSecureStorage = false,
  }) async {
    if (_loaded) return;

    _loadDartDefines();

    try {
      await dotenv.load(fileName: 'assets/env.defaults');
      // Optional local overlay — copy frontend/.env → assets/env.local for device builds.
      try {
        await dotenv.load(
          fileName: 'assets/env.local',
          mergeWith: dotenv.env,
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            'ℹ️ No assets/env.local — run: dart run tool/sync_env.dart '
            '(copies GOOGLE_MAPS_API_KEY from .env)',
          );
        }
      }

      // On-device override from secure storage (if previously saved).
      if (!hasGoogleMapsApiKey) {
        final storedMapsKey = await readSensitive('GOOGLE_MAPS_API_KEY');
        if (storedMapsKey.isNotEmpty) {
          _dartDefines['GOOGLE_MAPS_API_KEY'] = storedMapsKey;
        }
      }
      _loaded = true;
    } catch (e) {
      _loaded = false;
      debugPrint('⚠️ Env defaults load failed, using dart-define/fallbacks: $e');
    }

    if (persistSecretsToSecureStorage) {
      await _persistSensitiveEnvToSecureStorage();
    }
  }

  /// Read a sensitive value: secure-storage override first, then `.env`.
  static Future<String> readSensitive(String envKey) async {
    final override = await _secureStorage.read(key: _secureOverrideKey(envKey));
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return get(envKey);
  }

  /// Store a sensitive value only on-device (never commit to git).
  static Future<void> writeSensitiveOverride(
    String envKey,
    String value,
  ) async {
    await _secureStorage.write(
      key: _secureOverrideKey(envKey),
      value: value.trim(),
    );
  }

  static Future<void> clearSensitiveOverride(String envKey) async {
    await _secureStorage.delete(key: _secureOverrideKey(envKey));
  }

  static Future<String> get googleMapsApiKeySecure =>
      readSensitive('GOOGLE_MAPS_API_KEY').then((key) {
        if (key.isNotEmpty) return key;
        return googleMapsApiKey;
      });

  static Future<void> _persistSensitiveEnvToSecureStorage() async {
    const keys = <String>[
      'GOOGLE_MAPS_API_KEY',
      'FIREBASE_API_KEY',
      'SENTRY_DSN',
    ];
    for (final key in keys) {
      final value = get(key);
      if (value.isNotEmpty) {
        await writeSensitiveOverride(key, value);
      }
    }
  }

  /// Exposed for [StorageService] — same encrypted store, different keys.
  static FlutterSecureStorage get secureStorage => _secureStorage;
}
