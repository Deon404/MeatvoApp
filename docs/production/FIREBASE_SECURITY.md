# Firebase API Key Security

The file `frontend/android/app/google-services.json` contains a Firebase API key committed to the repository.

## Required Actions (Firebase Console)

1. Open [Firebase Console](https://console.firebase.google.com) → Project Settings
2. Under **API restrictions**, restrict the key to:
   - Firebase Cloud Messaging API
   - Firebase Installations API
3. Under **Application restrictions** (Android):
   - Package name: `com.meatvo.app`
   - SHA-1 fingerprints: debug + release signing certificates
4. Rotate the key if the repository was ever public
5. Monitor usage quotas for abuse

## Build-Time Injection (recommended long-term)

Move `google-services.json` generation to CI and add the file to `.gitignore`.
