import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_model.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';
import '../config/backend_resolver.dart';
import '../config/env_config.dart';
import 'api_service.dart';
import 'cart_service.dart';
import 'error_tracking_service.dart';
import 'push_notification_service.dart';
import 'storage_service.dart';

/// Result of POST `/auth/send-otp`.
class SendOtpResult {
  const SendOtpResult({
    this.devOtp,
    this.alreadySent = false,
    this.remainingSeconds,
  });

  final String? devOtp;
  final bool alreadySent;
  final int? remainingSeconds;
}

/// Authentication via custom Node backend ([EnvConfig.apiBaseUrl]).
/// Dio [ApiService] uses `baseUrl = {backendRoot}/api` (see [kBaseUrl]), so paths are `/auth/...`.
class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  static VoidCallback? _onLogoutCallback;

  static void registerLogoutCallback(VoidCallback callback) {
    _onLogoutCallback = callback;
  }

  // ── Auth state ──────────────────────────────────────────────────────────

  /// Sync flag cannot read secure storage; prefer [isLoggedInAsync].
  bool get isLoggedIn => false;

  Future<bool> get isLoggedInAsync async {
    final token = await _storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Cached user from [FlutterSecureStorage].
  Future<UserModel?> get currentUser => _storage.getUser();

  /// Alias for [currentUser] — kept for older call sites.
  Future<UserModel?> get currentUserAsync => _storage.getUser();

  /// Access token string for backend JWT access.
  Future<String?> get session => _storage.getAccessToken();

  // ── OTP flow ────────────────────────────────────────────────────────────

  /// Compatibility alias — returns [devOTP] when backend includes it (development).
  Future<String?> sendOTP(String phoneNumber) async {
    final result = await sendOtp(phoneNumber);
    return result.devOtp;
  }

  /// Sends OTP to phone through the Node backend.
  Future<void> signInWithOtp({
    required String phone,
    String? email,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
  }) async {
    await sendOtp(phone);
  }

  /// Same E.164 format used for send-otp and verify-otp (must match Redis key).
  static String formatPhoneE164(String phone) {
    return AuthService()._formatPhoneForSendOtp(phone);
  }

  /// POST `{backend}/api/auth/send-otp` — returns dev OTP when SMS skipped in development.
  Future<SendOtpResult> sendOtp(String phone, {bool resend = false}) async {
    try {
      final res = await _api
          .post(
            ApiAuthPaths.sendOtp,
            data: {
              'phone': _formatPhoneForSendOtp(phone),
              if (resend) 'resend': true,
            },
          )
          .timeout(
            ApiConfig.authTimeout,
            onTimeout: () {
              BackendResolver.logConnectionDevHint();
              throw Exception(BackendResolver.connectionUserMessage());
            },
          );

      String? devOtp;
      if (!EnvConfig.isProduction && !kReleaseMode) {
        final root = res.data;
        if (root is Map<String, dynamic>) {
          final data = root['data'];
          if (data is Map<String, dynamic>) {
            final dev = data['devOTP']?.toString();
            if (dev != null && dev.isNotEmpty) devOtp = dev;
          }
        }
      }
      return SendOtpResult(devOtp: devOtp);
    } on DioException catch (e) {
      final existing = _parseExistingOtpResponse(e);
      if (existing != null) return existing;
      throw Exception(_extractErrorMessage(e, 'Failed to send OTP'));
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Compatibility alias used by existing screens.
  Future<UserModel> verifyOTP(String phoneNumber, String otp) =>
      verifyOtp(phoneNumber, otp);

  /// POST `{backend}/api/auth/verify-otp`
  /// Body: `{ phone: "+91XXXXXXXXXX", otp: "1234" }`
  /// Response `data`: `{ token, refreshToken, user }`
  Future<UserModel> verifyOtp(String phone, String otp) async {
    try {
      final res = await _api.post(ApiAuthPaths.verifyOtp, data: {
        'phone': _formatPhoneForSendOtp(phone),
        'otp': otp,
      });

      final root = res.data as Map<String, dynamic>;
      final payload = (root['data'] ?? root) as Map<String, dynamic>;

      final token = (payload['token'] ?? payload['accessToken'] ?? '').toString();
      final refreshToken = (payload['refreshToken'] ?? '').toString();

      if (token.isEmpty || refreshToken.isEmpty) {
        throw Exception('Invalid auth response: missing token(s)');
      }

      final userJson = _extractUserMap(payload);
      final normalizedUser = _normalizeUserJson(userJson);
      // Do not copyWith(role: ...) from normalized map — it uses ADMIN/CUSTOMER
      // uppercase strings and breaks routing that expects lowercase admin/rider/customer.
      final user = UserModel.fromJson(normalizedUser);

      await _storage.saveTokens(token, refreshToken);
      await _storage.saveUser(user);

      await ErrorTrackingService.setUser(
        id: user.id,
        username: user.phoneNumber,
        data: {'role': user.role},
      );

      // Register push token in background — do not block login on FCM retries.
      unawaited(PushNotificationService().syncTokenWithBackend());

      if (kDebugMode) {
        debugPrint('[AuthService] Session established for user ${user.id}');
      }

      return user;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'OTP verification failed'));
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // ── Profile ─────────────────────────────────────────────────────────────

  /// GET `{backend}/api/auth/me`
  Future<UserModel?> getMe() async {
    try {
      final res = await _api.get(ApiAuthPaths.me);
      final root = res.data as Map<String, dynamic>;
      final payload = root['data'] ?? root;
      if (payload is! Map<String, dynamic>) {
        return await _storage.getUser();
      }

      final userJson = _extractUserMap(payload);
      if (userJson.isEmpty) {
        return await _storage.getUser();
      }

      final normalizedUser = _normalizeUserJson(userJson);
      final user = UserModel.fromJson(normalizedUser);
      await _storage.saveUser(user);
      return user;
    } catch (_) {
      return await _storage.getUser();
    }
  }

  /// GET `{backend}/health` (not under `/api`)
  /// Returns true when backend responds with status=ok.
  Future<bool> healthCheck() async {
    try {
      final res = await Dio().get('${EnvConfig.apiBaseUrl}/health');
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final payload = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : data;
        return payload['status']?.toString().toLowerCase() == 'ok';
      }
      return false;
    } catch (e) {
      throw Exception('Health check request failed: $e');
    }
  }

  /// Compatibility method used by current app routes/screens.
  Future<UserModel?> getCurrentUserProfile() async {
    final cached = await _storage.getUser();
    if (cached != null) return cached;
    return getMe();
  }

  /// PATCH `{backend}/api/users/profile`
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? profileImageUrl,
  }) async {
    final current = await _storage.getUser();
    if (current == null) throw Exception('User not logged in');

    try {
      final res = await _api.patch(
        ApiUserPaths.profile,
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
        },
      );
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final profile = Map<String, dynamic>.from(data['data'] as Map);
        final updated = current.copyWith(
          name: profile['name']?.toString() ?? name ?? current.name,
          email: profile['email']?.toString() ?? email ?? current.email,
          profileImageUrl:
              profile['profile_image_url']?.toString() ?? profileImageUrl ?? current.profileImageUrl,
        );
        await _storage.saveUser(updated);
        return updated;
      }
    } catch (_) {
      // Fall back to local save if offline
    }

    final updated = current.copyWith(
      name: name ?? current.name,
      email: email ?? current.email,
      profileImageUrl: profileImageUrl ?? current.profileImageUrl,
    );
    await _storage.saveUser(updated);
    return updated;
  }

  // ── Logout ──────────────────────────────────────────────────────────────

  /// Compatibility alias used by existing screens.
  Future<void> signOut() => logout();

  /// POST `{backend}/api/auth/logout` (Bearer token when available), then clear storage.
  Future<void> logout() async {
    try {
      await _api.post(ApiAuthPaths.logout);
    } catch (_) {
      // Ignore logout network failure and clear local session.
    } finally {
      await ErrorTrackingService.clearUser();
      await _storage.clear();

      // Clear cart notifiers
      CartService.cartNotifier.value = CartModel();
      CartService.cartItemCountNotifier.value = 0;

      // Clear checkout preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('meatvo_checkout_payment_option');

      // Clear wishlist cache
      await prefs.remove('wishlist_product_ids');

      _onLogoutCallback?.call();
    }
  }

  Future<void> resendOTP(String phoneNumber) async {
    await sendOtp(phoneNumber, resend: true);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  SendOtpResult? _parseExistingOtpResponse(DioException e) {
    if (e.response?.statusCode != 429) return null;

    final raw = e.response?.data;
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final nestedError = map['error'];
    final message = (map['message'] ??
            (nestedError is Map ? nestedError['message'] : null) ??
            '')
        .toString()
        .toLowerCase();
    if (!message.contains('already sent')) return null;

    int? remainingSeconds;
    final payload = map['data'];
    if (payload is Map) {
      final value = payload['remainingSeconds'];
      if (value is num) remainingSeconds = value.toInt();
    }

    return SendOtpResult(
      alreadySent: true,
      remainingSeconds: remainingSeconds,
    );
  }

  String _formatPhoneForSendOtp(String input) {
    var normalized = input.trim().replaceAll(RegExp(r'\s+'), '');

    if (normalized.startsWith('+')) {
      return normalized;
    }

    var digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    if (RegExp(r'^\d{10}$').hasMatch(digits)) {
      return '+91$digits';
    }

    return '+$digits';
  }

  String _extractErrorMessage(DioException e, String fallback) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      BackendResolver.logConnectionDevHint();
      return BackendResolver.connectionUserMessage();
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }

  /// Unwraps `{ user: {...} }` envelopes from auth API responses.
  Map<String, dynamic> _extractUserMap(Map<String, dynamic> payload) {
    final nested = payload['user'];
    if (nested is Map<String, dynamic>) {
      return Map<String, dynamic>.from(nested);
    }
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return Map<String, dynamic>.from(payload);
  }

  /// Light field normalization before [UserModel.fromJson] (role mapping lives there).
  Map<String, dynamic> _normalizeUserJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);

    if (!copy.containsKey('phone') && copy.containsKey('phoneNumber')) {
      copy['phone'] = copy['phoneNumber'];
    }

    return copy;
  }
}
