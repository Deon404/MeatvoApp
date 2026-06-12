# Token Refresh Issue - Debugging Guide

## Problem Summary

The rider app is experiencing authentication failures when trying to update order status. The error sequence is:

1. **403 "Order not assigned to you"** - First status update attempt fails
2. **401 "Not authorized"** - Subsequent requests fail due to expired/invalid token
3. **"Refresh token unavailable"** - App cannot refresh the session
4. **User logged out** - App clears all tokens and redirects to login screen

## Root Cause Analysis

The core issue is that **the refresh token is missing from secure storage** when the app tries to refresh the access token. This could be caused by:

1. **Refresh token not saved during login** - Backend didn't return it or app didn't persist it
2. **Secure storage failure** - Android `encryptedSharedPreferences` not persisting properly
3. **Token cleared prematurely** - Some code path is clearing tokens when it shouldn't
4. **App restart/crash** - Token lost (but secure storage should persist across restarts)

## Changes Made

### Added Comprehensive Logging

I've added detailed logging to track the entire token lifecycle:

#### 1. Storage Service (`lib/services/storage_service.dart`)
- **`saveTokens()`** - Logs when tokens are saved with their lengths
- **`getAccessToken()`** - Logs when access token is retrieved (present/NULL)
- **`getRefreshToken()`** - Logs when refresh token is retrieved (present/NULL)
- **`clear()`** - Logs when storage is cleared

#### 2. Auth Service (`lib/services/auth_service.dart`)
- **`verifyOtp()`** - Logs after tokens are saved to verify persistence

#### 3. API Client (`lib/services/api_client.dart`)
- **`_onRequest()`** - Logs whether requests have auth tokens
- **`_refreshAccessToken()`** - Logs refresh token availability and refresh process
- **Error handler** - Logs when refresh fails and storage is cleared

## Testing Instructions

### Step 1: Clean Reinstall
```bash
cd old_meatvo
flutter clean
flutter pub get
flutter run
```

### Step 2: Login as Rider
1. Open the rider app
2. Login with your rider phone number
3. **Watch the console logs** for these messages:
   ```
   [StorageService] Saving tokens - Access: XXX chars, Refresh: XXX chars
   [StorageService] Tokens saved successfully
   [AuthService] Tokens saved - Access: ...first 20 chars..., Refresh: ...first 20 chars...
   ```
4. If you see **`Refresh: XXX chars`**, the token WAS saved
5. If you see **`Refresh: 0 chars`** or errors, the backend didn't return a refresh token

### Step 3: Reproduce the Issue
1. Wait for an order assignment or create a test order
2. Go to the order detail screen
3. Click **"Mark Picked Up"**
4. **Watch the console logs** for:
   ```
   [RiderOrderDetail] Marking picked up: XX
   [ApiClient] Request to /api/delivery/orders/XX/status with auth token
   [StorageService] Retrieved access token: present (XXX chars)
   [ApiClient] Attempting token refresh - Refresh token available: true/false
   ```

### Step 4: Check for 401 Errors
If you see a 401 error, check if the refresh flow is triggered:
```
[ApiClient] Attempting token refresh - Refresh token available: false
[ApiClient] ERROR: Refresh token is missing from secure storage!
[ApiClient] Token refresh failed: Bad state: Refresh token unavailable
[ApiClient] Clearing all storage and notifying session expired
[StorageService] Clearing all tokens and user data
```

## Expected Behavior

### Normal Flow (Success):
1. Login → Tokens saved (both access & refresh)
2. API request → Access token sent
3. Access token expires → 401 error
4. Refresh token retrieved → Refresh request sent
5. New tokens received → New tokens saved
6. Original request retried → Success

### Current Flow (Failure):
1. Login → Tokens saved? (need to verify)
2. API request → Access token sent
3. 403 error (business logic) → NOT auth related
4. Separate request gets 401 → Triggers refresh
5. Refresh token retrieval → **NULL/missing**
6. Refresh fails → Storage cleared → User logged out

## Potential Solutions

### Solution 1: Verify Backend Response
Check if the backend is actually returning a refresh token for rider logins:
```bash
# Watch backend logs when rider logs in
# Check the verify-otp response includes refreshToken field
```

### Solution 2: Check Secure Storage Permissions
The app uses Android `encryptedSharedPreferences`. Verify:
- Android manifest has proper permissions
- Device supports encrypted shared preferences
- No OS-level security policies preventing storage

### Solution 3: Increase Token Expiry
If the access token expires too quickly, increase the expiry time in the backend:
```javascript
// backend/src/utils/jwt.js or similar
this.accessTokenExpiry = '30m'; // Increase from 15m to 30m
```

### Solution 4: Handle 403 Separately
The 403 "Order not assigned to you" error might indicate:
- Order was reassigned to another rider
- Assignment expired
- Database mismatch between order and assignment

This is a **business logic error**, not an authentication error. Handle it separately:
```dart
// In rider_service.dart updateOrderStatus()
if (e.response?.statusCode == 403) {
  final message = e.response?.data?['message'] ?? 'Action not allowed';
  if (message.contains('not assigned')) {
    throw OrderNotAssignedException(message);
  }
}
```

## Next Steps

1. **Run the app with logging enabled** and watch the console during login
2. **Capture the full log** from login through error
3. **Share the log** to identify exactly where the token is lost
4. **Check the backend verify-otp response** to ensure it includes `refreshToken`

## Testing Checklist

- [ ] Login as rider and verify tokens are saved (check console logs)
- [ ] Make a successful API request and verify token is sent
- [ ] Wait for access token to expire or force a 401 error
- [ ] Verify refresh token is retrieved from storage
- [ ] Verify refresh request is sent and succeeds
- [ ] Verify new tokens are saved
- [ ] Verify original request is retried successfully

## Files Modified

1. `old_meatvo/lib/services/storage_service.dart` - Added logging to track token storage
2. `old_meatvo/lib/services/auth_service.dart` - Added logging after token save
3. `old_meatvo/lib/services/api_client.dart` - Added logging throughout refresh flow

---

**Last Updated:** June 8, 2026
**Status:** Debugging in progress
**Priority:** Critical - Blocks all rider order operations
