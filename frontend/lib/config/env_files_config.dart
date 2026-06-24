/// Canonical registry of frontend env files and keys.
/// Machine-readable source: [envManifestPath] (`frontend/env.manifest.json`).
library;

/// Paths relative to the `frontend/` package root.
class EnvFilesConfig {
  EnvFilesConfig._();

  static const envManifestPath = 'env.manifest.json';

  // ── Secret / local files (gitignored) ───────────────────────────────────

  static const localDotEnv = '.env';
  static const localDotEnvTemplate = '.env.example';
  static const productionJson = 'env.production.json';
  static const productionJsonTemplate = 'env.production.example.json';
  static const localJson = 'env.local.json';

  static const runtimeDefaultsAsset = 'assets/env.defaults';
  static const runtimeLocalAsset = 'assets/env.local';
  static const runtimeLocalExample = 'assets/env.local.example';

  static const androidSecrets = 'android/secrets.properties';
  static const androidSecretsExample = 'android/secrets.properties.example';
  static const googleServicesLocal = 'android/app/google-services.local.json';
  static const googleServicesBuild = 'android/app/google-services.json';
  static const androidKeystoreProperties = 'android/keystore.properties';

  /// Runtime resolution order (highest priority first).
  static const loadPriority = <String>[
    '--dart-define / --dart-define-from-file',
    runtimeLocalAsset,
    runtimeDefaultsAsset,
  ];

  /// Keys copied from [localDotEnv] → [runtimeLocalAsset] by `tool/sync_env.dart`.
  static const syncKeys = <String>[
    'APP_ENV',
    'API_BASE_URL',
    'GOOGLE_MAPS_API_KEY',
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',
    'MEATVO_API_ROOT',
    'BACKEND_ROOT_URL',
    'API_URL',
    'CASHFREE_ENV',
  ];

  /// Required for production APK/AAB (`env.production.json` / dart-define).
  static const productionBuildKeys = <String>[
    'API_BASE_URL',
    'APP_ENV',
    'CASHFREE_ENV',
    'GOOGLE_MAPS_API_KEY',
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_STORAGE_BUCKET',
  ];

  /// Must never appear in Flutter env files or APK dart-defines.
  static const neverInClient = <String>[
    'JWT_ACCESS_SECRET',
    'JWT_REFRESH_SECRET',
    'OTP_HASH_SECRET',
    'CASHFREE_SECRET_KEY',
    'FCM_SERVER_KEY',
    'FIREBASE_SERVICE_ACCOUNT_JSON',
    'DB_PASSWORD',
  ];
}
