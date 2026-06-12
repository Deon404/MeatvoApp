import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Drop-in compatibility shim that preserves the old config API shape
/// so screens don't need to be rewritten all at once.
///
/// Find & Replace in the codebase:
///   Old config imports  →  "app_config.dart"
///   Old config access   →  AppConfig.
///
/// All properties are async because the underlying JWT storage is async.
class AppConfig {
  static final _auth    = AuthService();
  static final _storage = StorageService();

  // ── Auth state ────────────────────────────────────────────────────────────

  /// True if a valid JWT access token is stored.
  static Future<bool> get isLoggedIn async {
    final token = await _storage.getAccessToken();
    return token != null;
  }

  /// Currently cached user, or null if not logged in.
  static Future<UserModel?> get currentUser => _auth.getCurrentUserProfile();

  /// Shortcut for the current user's UUID.
  static Future<String?> get currentUserId async {
    final user = await _storage.getUser();
    return user?.id;
  }

  /// Current user role string: 'customer' | 'admin' | 'rider'.
  static Future<String?> get currentRole async {
    final user = await _storage.getUser();
    return user?.role;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() => _auth.signOut();
}
