import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState.initial());

  Future<void> bootstrap() async {
    final hasSession = await _ref.read(authServiceProvider).hasSession();
    if (hasSession) {
      final user = await _ref.read(authServiceProvider).getMe();
      state = AuthState.authenticated(user: user);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> sendOtp(String phone) async {
    state = const AuthState.loading();
    try {
      await _ref.read(authServiceProvider).sendOtp(phone);
      state = AuthState.otpSent(phone);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = const AuthState.loading();
    try {
      final user = await _ref.read(authServiceProvider).verifyOtp(phone, otp);
      state = AuthState.authenticated(user: user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    state = const AuthState.unauthenticated();
  }
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? phone;
  final String? error;
  final UserModel? user;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.phone,
    this.error,
    this.user,
  });

  const AuthState.initial()
      : isLoading = true,
        isAuthenticated = false,
        phone = null,
        error = null,
        user = null;

  const AuthState.loading()
      : isLoading = true,
        isAuthenticated = false,
        phone = null,
        error = null,
        user = null;

  const AuthState.unauthenticated()
      : isLoading = false,
        isAuthenticated = false,
        phone = null,
        error = null,
        user = null;

  const AuthState.authenticated({this.user})
      : isLoading = false,
        isAuthenticated = true,
        phone = null,
        error = null;

  const AuthState.otpSent(this.phone)
      : isLoading = false,
        isAuthenticated = false,
        error = null,
        user = null;

  const AuthState.error(this.error)
      : isLoading = false,
        isAuthenticated = false,
        phone = null,
        user = null;
}
