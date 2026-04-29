import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  Future<void> sendOtp(String phone) async {
    await _ref.read(apiServiceProvider).post('/auth/send-otp', data: {'phone': phone});
  }

  Future<UserModel> verifyOtp(String phone, String otp) async {
    final response = await _ref.read(apiServiceProvider).post(
      '/auth/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );

    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final user = UserModel.fromJson((data['user'] ?? const {}) as Map<String, dynamic>);
    final access = (data['accessToken'] ?? data['token'] ?? '').toString();
    final refresh = (data['refreshToken'] ?? '').toString();
    if (access.isEmpty || refresh.isEmpty) {
      throw Exception('Invalid auth tokens');
    }

    await _ref.read(storageServiceProvider).saveTokens(
          accessToken: access,
          refreshToken: refresh,
        );

    return user;
  }

  Future<bool> hasSession() async {
    final token = await _ref.read(storageServiceProvider).getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<UserModel?> getMe() async {
    try {
      final response = await _ref.read(apiServiceProvider).get('/auth/me');
      final payload = response.data as Map<String, dynamic>;
      final data = (payload['data'] ?? payload) as Map<String, dynamic>;
      final userRaw = data['user'] as Map<String, dynamic>?;
      if (userRaw == null) return null;
      return UserModel.fromJson(userRaw);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _ref.read(storageServiceProvider).clear();
  }
}
