import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

class UiState {
  const UiState({
    required this.isGlobalLoading,
    required this.errorMessage,
    required this.themeMode,
  });

  factory UiState.initial(ThemeMode themeMode) => UiState(
        isGlobalLoading: false,
        errorMessage: null,
        themeMode: themeMode,
      );

  final bool isGlobalLoading;
  final String? errorMessage;
  final ThemeMode themeMode;

  UiState copyWith({
    bool? isGlobalLoading,
    Object? errorMessage = _sentinel,
    ThemeMode? themeMode,
  }) {
    return UiState(
      isGlobalLoading: isGlobalLoading ?? this.isGlobalLoading,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

const Object _sentinel = Object();

final uiProvider = StateNotifierProvider<UiNotifier, UiState>((ref) {
  return UiNotifier(ref)..syncTheme();
});

class UiNotifier extends StateNotifier<UiState> {
  UiNotifier(this._ref) : super(UiState.initial(_ref.read(themeProvider)));

  final Ref _ref;

  void setLoading(bool value) {
    state = state.copyWith(isGlobalLoading: value);
  }

  void setError(String? message) {
    state = state.copyWith(errorMessage: message);
  }

  Future<void> toggleTheme() async {
    await _ref.read(themeProvider.notifier).toggleTheme();
    syncTheme();
  }

  void syncTheme() {
    state = state.copyWith(themeMode: _ref.read(themeProvider));
  }
}
