import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env_config.dart';
import '../models/user_model.dart';

/// Secure token & user storage using [EnvConfig.secureStorage] key names from `.env`.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static String get keyAccessToken => EnvConfig.secureStorageAccessTokenKey;

  static String get keyRefreshToken => EnvConfig.secureStorageRefreshTokenKey;

  static String get keyUser => EnvConfig.secureStorageUserDataKey;

  // ── Tokens ─────────────────────────────────────────────────────────────

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final storage = EnvConfig.secureStorage;
    if (kDebugMode) {
      debugPrint('[StorageService] Saving tokens - Access: ${accessToken.length} chars, Refresh: ${refreshToken.length} chars');
    }
    await Future.wait([
      storage.write(key: keyAccessToken, value: accessToken),
      storage.write(key: keyRefreshToken, value: refreshToken),
    ]);
    if (kDebugMode) {
      debugPrint('[StorageService] Tokens saved successfully');
    }
  }

  Future<String?> getAccessToken() async {
    final token = await EnvConfig.secureStorage.read(key: keyAccessToken);
    if (kDebugMode) {
      debugPrint('[StorageService] Retrieved access token: ${token != null ? "present (${token.length} chars)" : "NULL"}');
    }
    return token;
  }

  Future<String?> getRefreshToken() async {
    final token = await EnvConfig.secureStorage.read(key: keyRefreshToken);
    if (kDebugMode) {
      debugPrint('[StorageService] Retrieved refresh token: ${token != null ? "present (${token.length} chars)" : "NULL"}');
    }
    return token;
  }

  // ── User ───────────────────────────────────────────────────────────────

  Future<void> saveUser(UserModel user) async {
    await EnvConfig.secureStorage.write(
      key: keyUser,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<UserModel?> getUser() async {
    final raw = await EnvConfig.secureStorage.read(key: keyUser);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Clear ──────────────────────────────────────────────────────────────

  Future<void> clear() async {
    if (kDebugMode) {
      debugPrint('[StorageService] Clearing all tokens and user data');
    }
    final storage = EnvConfig.secureStorage;
    await Future.wait([
      storage.delete(key: keyAccessToken),
      storage.delete(key: keyRefreshToken),
      storage.delete(key: keyUser),
    ]);
    if (kDebugMode) {
      debugPrint('[StorageService] Storage cleared successfully');
    }
  }
}
