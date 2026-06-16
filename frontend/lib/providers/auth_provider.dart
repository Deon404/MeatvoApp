import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

class AuthState {
  const AuthState({
    required this.isInitializing,
    required this.isSubmitting,
    required this.user,
    required this.error,
  });

  factory AuthState.initial() => const AuthState(
        isInitializing: true,
        isSubmitting: false,
        user: null,
        error: null,
      );

  final bool isInitializing;
  final bool isSubmitting;
  final UserModel? user;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isInitializing,
    bool? isSubmitting,
    Object? user = _sentinel,
    Object? error = _sentinel,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      user: identical(user, _sentinel) ? this.user : user as UserModel?,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthService())..initialize();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(AuthState.initial());

  final AuthService _authService;

  Future<void> initialize() async {
    state = state.copyWith(isInitializing: true, error: null);
    try {
      final user = await _authService.getCurrentUserProfile();
      if (user != null) {
        await SocketService().connect();
      }
      state = state.copyWith(
        isInitializing: false,
        user: user,
      );
    } catch (error) {
      state = state.copyWith(
        isInitializing: false,
        error: _message(error, fallback: 'Could not load your session.'),
      );
    }
  }

  Future<bool> sendOtp(String phoneNumber) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _authService.sendOtp(phoneNumber);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _message(error, fallback: 'Could not send OTP. Please try again.'),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final user = await _authService.verifyOtp(phoneNumber, otp);
      await SocketService().connect();
      state = state.copyWith(
        isSubmitting: false,
        user: user,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _message(error, fallback: 'Could not verify OTP. Please try again.'),
      );
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _authService.getMe();
      state = state.copyWith(user: user, error: null);
    } catch (error) {
      state = state.copyWith(
        error: _message(error, fallback: 'Could not refresh your profile.'),
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _authService.signOut();
      SocketService().disconnect();
      state = state.copyWith(
        isSubmitting: false,
        user: null,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _message(error, fallback: 'Could not sign out. Please try again.'),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  String _message(Object error, {required String fallback}) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    return raw.isEmpty ? fallback : raw;
  }
}
