import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration and initialization
class FirebaseConfig {
  static bool _initialized = false;

  /// Initialize Firebase
  /// 
  /// Note: Make sure to add google-services.json (Android) and 
  /// GoogleService-Info.plist (iOS) files before calling this.
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('Firebase already initialized');
      return;
    }

    try {
      await Firebase.initializeApp();
      _initialized = true;
      debugPrint('✅ Firebase initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('⚠️ App will continue in bypass mode (use PIN 404040 for testing)');
      
      // If Firebase is not configured, app can still run
      // but authentication won't work (bypass mode available)
      _initialized = false;
      // Don't rethrow - allow app to continue with bypass mode
    }
  }

  /// Check if Firebase is initialized
  static bool get isInitialized => _initialized;
}

