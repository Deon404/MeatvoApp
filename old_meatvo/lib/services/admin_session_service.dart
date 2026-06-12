/// AdminSessionService — no-op after migration to custom backend.
/// Admin authentication is now handled via JWT bearer token in ApiService.
class AdminSessionService {
  static Future<void> ensureSignedIn() async {
    // No-op: admin auth is done at login time via verifyOtp()
    // The JWT token is auto-attached to every request by ApiService._AuthInterceptor
  }
}
