// Generated from android/app/google-services.json (meatvo-4c1e5).
// Re-run `flutterfire configure` when adding iOS/web targets.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
          'add GoogleService-Info.plist and run flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDLKIHwhFbG3cZ_qkmh8LJJBBvC4pcf-gA',
    appId: '1:666934912223:android:1d46ae140f815fdc21b56a',
    messagingSenderId: '666934912223',
    projectId: 'meatvo-4c1e5',
    storageBucket: 'meatvo-4c1e5.firebasestorage.app',
  );
}
