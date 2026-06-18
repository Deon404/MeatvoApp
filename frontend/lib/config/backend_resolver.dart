import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env_config.dart';

/// Picks a reachable backend URL before API calls (fixes physical phone + wrong 10.0.2.2).
class BackendResolver {
  BackendResolver._();

  static const _prefKey = 'meatvo_resolved_backend_root';
  static String? _resolvedRoot;
  static bool _hasReachableBackend = false;
  static DateTime? _lastProbeAttempt;
  static Future<void>? _probeInFlight;

  static bool get hasReachableBackend => _hasReachableBackend;

  /// True when env provides a backend URL — allow API attempts even if startup probe failed.
  static bool get hasConfiguredBackend => EnvConfig.configuredBackendRoot != null;

  /// Reachable backend root, or [EnvConfig.apiBaseUrl] when probes all failed.
  static String get root {
    if (_hasReachableBackend && _resolvedRoot != null) {
      return _resolvedRoot!;
    }
    return EnvConfig.apiBaseUrl;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey)?.trim();

    // Production release APK: trust configured HTTPS domain (health probe may be nginx-restricted).
    if (EnvConfig.isProduction) {
      final configured = EnvConfig.configuredBackendRoot;
      if (configured != null) {
        _resolvedRoot = configured;
        _hasReachableBackend = true;
        await prefs.setString(_prefKey, configured);
        debugPrint('✅ Production backend: $configured');
        return;
      }
    }

    final candidates = <String>[];
    void add(String? url) {
      final normalized = EnvConfig.normalizeBackendRoot(url);
      if (normalized != null) candidates.add(normalized);
    }

    if (EnvConfig.isDevelopment && !kIsWeb && Platform.isAndroid) {
      // USB debugging (adb reverse tcp:8080 tcp:8080) — try before LAN IP.
      add('http://127.0.0.1:8080');
      add('http://10.0.2.2:8080');
    }

    add(EnvConfig.configuredBackendRoot);
    add(saved);

    if (EnvConfig.isDevelopment) {
      add(EnvConfig.apiBaseUrl);
    }

    final unique = <String>[];
    for (final c in candidates) {
      if (!unique.contains(c)) unique.add(c);
    }

    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
      ),
    );

    for (final base in unique) {
      try {
        final res = await probe.get<String>('$base/health/live');
        if (res.statusCode == 200) {
          _resolvedRoot = base;
          _hasReachableBackend = true;
          await prefs.setString(_prefKey, base);
          debugPrint('✅ Backend resolved: $base');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Backend probe failed ($base): $e');
      }
    }

    // Do not fall back to an unreachable configured URL — leaves root unset so
    // callers surface [connectionHelpMessage] instead of silent DNS failures.
    _resolvedRoot = null;
    _hasReachableBackend = false;
    await prefs.remove(_prefKey);
    debugPrint('⚠️ No reachable backend. Set MEATVO_API_ROOT in .env '
        '(PC LAN IP on physical device).');
  }

  static const String connectionErrorPrefix = 'Cannot reach the server';

  /// Short message shown in the app UI.
  static String connectionUserMessage() {
    return 'Unable to connect to the server. '
        'Please check your internet connection and try again.';
  }

  /// Detailed setup hints — debug console only.
  static String connectionHelpMessage() {
    if (EnvConfig.isProduction) {
      return 'Cannot reach ${EnvConfig.apiBaseUrl}. '
          'Check your internet connection or try again later.';
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'Cannot reach backend.\n\n'
          '• Physical phone (Wi‑Fi): set API_BASE_URL=http://YOUR_PC_IP:8080 '
          'in frontend/.env, then run: dart run tool/sync_env.dart\n'
          '• USB debugging: adb reverse tcp:8080 tcp:8080, then '
          'MEATVO_API_ROOT=http://127.0.0.1:8080\n'
          '• Emulator: MEATVO_API_ROOT=http://10.0.2.2:8080\n\n'
          'Start backend: cd backend && npm run dev';
    }
    return 'Cannot reach backend. Start it with: cd backend && npm run dev '
        'and set MEATVO_API_ROOT in frontend/.env.';
  }

  /// Re-probe when startup failed or backend came up later (debounced).
  static Future<void> ensureReachable() async {
    if (_hasReachableBackend) return;

    final now = DateTime.now();
    if (_lastProbeAttempt != null &&
        now.difference(_lastProbeAttempt!) < const Duration(seconds: 3)) {
      return;
    }

    _probeInFlight ??= init().whenComplete(() {
      _lastProbeAttempt = DateTime.now();
      _probeInFlight = null;
    });
    await _probeInFlight;
  }

  static bool isConnectionError(String message) {
    final lower = message.toLowerCase();
    return lower.contains(connectionErrorPrefix.toLowerCase()) ||
        lower.contains('unable to connect to the server') ||
        lower.contains('cannot reach') ||
        lower.contains('connection error') ||
        lower.contains('connection refused') ||
        lower.contains('connection timeout') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('socketexception') ||
        lower.contains('server tak nahi');
  }

  static String toUserMessage(
    Object error, {
    String? fallback,
  }) {
    final raw = error.toString().replaceFirst('Exception:', '').trim();
    if (isConnectionError(raw)) return connectionUserMessage();
    if (raw.isEmpty) {
      return fallback ?? 'Something went wrong. Please try again.';
    }
    return raw;
  }

  static void logConnectionDevHint() {
    if (kDebugMode) {
      debugPrint('Backend connection hint: ${connectionHelpMessage()}');
    }
  }
}
