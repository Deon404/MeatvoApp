// Firebase options from `.env` / `--dart-define` via [EnvConfig].
// Set FIREBASE_* keys in frontend/.env (see .env.example), then: dart run tool/sync_env.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'config/env_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS — '
          'add GoogleService-Info.plist and FIREBASE_* env keys.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _require('FIREBASE_API_KEY'),
        appId: _require('FIREBASE_APP_ID'),
        messagingSenderId: _require('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _require('FIREBASE_PROJECT_ID'),
        storageBucket: _require('FIREBASE_STORAGE_BUCKET'),
      );

  static String _require(String key) {
    final value = EnvConfig.get(key);
    if (value.isEmpty) {
      throw StateError(
        'Missing $key — set in frontend/.env and run: dart run tool/sync_env.dart',
      );
    }
    return value;
  }
}
