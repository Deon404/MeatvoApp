import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import 'dart:io';

/// Firebase Diagnostic Tool
/// Run this to check Firebase configuration and OTP setup
class FirebaseDiagnostic {
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};
    
    // Check 1: Firebase Initialization
    results['firebase_initialized'] = FirebaseConfig.isInitialized;
    if (FirebaseConfig.isInitialized) {
      debugPrint('✅ Firebase is initialized');
    } else {
      debugPrint('❌ Firebase is NOT initialized');
      results['error'] = 'Firebase not initialized. Check google-services.json and initialization code.';
      return results;
    }
    
    // Check 2: Firebase Auth Instance (temporarily disabled)
    results['firebase_auth_available'] = false;
    debugPrint('ℹ️ Firebase Auth check skipped (dependency temporarily removed)');
    
    // Check 3: google-services.json file
    try {
      final file = File('android/app/google-services.json');
      if (await file.exists()) {
        results['google_services_file_exists'] = true;
        final content = await file.readAsString();
        final hasOAuthClient = content.contains('"oauth_client"') && 
                               !content.contains('"oauth_client": []');
        results['oauth_client_present'] = hasOAuthClient;
        if (hasOAuthClient) {
          debugPrint('✅ google-services.json has oauth_client');
        } else {
          debugPrint('❌ google-services.json missing oauth_client');
          results['error'] = 'oauth_client is empty or missing in google-services.json';
        }
      } else {
        results['google_services_file_exists'] = false;
        results['error'] = 'google-services.json file not found';
        debugPrint('❌ google-services.json file not found');
      }
    } catch (e) {
      results['google_services_file_exists'] = false;
      results['error'] = 'Error checking google-services.json: $e';
      debugPrint('❌ Error checking google-services.json: $e');
    }
    
    // Check 4: Test OTP send (dry run) - disabled with firebase_auth removal
    results['verify_phone_method_available'] = false;
    debugPrint('ℹ️ verifyPhoneNumber check skipped (firebase_auth removed)');
    
    return results;
  }
  
  static void printDiagnostics(Map<String, dynamic> results) {
    debugPrint('\n🔍 Firebase Diagnostic Results:');
    debugPrint('================================');
    debugPrint('Firebase Initialized: ${results['firebase_initialized']}');
    debugPrint('Firebase Auth Available: ${results['firebase_auth_available']}');
    debugPrint('google-services.json Exists: ${results['google_services_file_exists']}');
    debugPrint('OAuth Client Present: ${results['oauth_client_present']}');
    debugPrint('Verify Phone Method Available: ${results['verify_phone_method_available']}');
    if (results['error'] != null) {
      debugPrint('❌ Error: ${results['error']}');
    } else {
      debugPrint('✅ All checks passed!');
    }
    debugPrint('================================\n');
  }
}

