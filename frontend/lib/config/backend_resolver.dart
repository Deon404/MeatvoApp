import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_session_log.dart';
import 'env_config.dart';

/// Picks a reachable backend URL before API calls (fixes physical phone + wrong 10.0.2.2).
class BackendResolver {
  BackendResolver._();

  static const _prefKey = 'meatvo_resolved_backend_root';
  static String? _resolvedRoot;
  static bool _hasReachableBackend = false;

  static bool get hasReachableBackend => _hasReachableBackend;

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

    // #region agent log
    DebugSessionLog.log(
      location: 'backend_resolver.dart:init',
      message: 'backend resolver starting',
      hypothesisId: 'H1',
      data: {
        'configuredRoot': EnvConfig.configuredBackendRoot,
        'savedRoot': saved,
        'platform': Platform.operatingSystem,
      },
    );
    // #endregion

    final candidates = <String>[];
    void add(String? url) {
      final normalized = EnvConfig.normalizeBackendRoot(url);
      if (normalized != null) candidates.add(normalized);
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
        final res = await probe.get<String>('$base/health');
        if (res.statusCode == 200) {
          _resolvedRoot = base;
          _hasReachableBackend = true;
          await prefs.setString(_prefKey, base);
          debugPrint('✅ Backend resolved: $base');
          // #region agent log
          DebugSessionLog.log(
            location: 'backend_resolver.dart:probe',
            message: 'backend probe succeeded',
            hypothesisId: 'H1',
            data: {'resolvedRoot': base},
          );
          // #endregion
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Backend probe failed ($base): $e');
        // #region agent log
        DebugSessionLog.log(
          location: 'backend_resolver.dart:probe',
          message: 'backend probe failed',
          hypothesisId: 'H1',
          data: {'candidate': base, 'error': e.runtimeType.toString()},
        );
        // #endregion
      }
    }

    // Do not fall back to an unreachable configured URL — leaves root unset so
    // callers surface [connectionHelpMessage] instead of silent DNS failures.
    _resolvedRoot = null;
    _hasReachableBackend = false;
    await prefs.remove(_prefKey);
    debugPrint('⚠️ No reachable backend. Set MEATVO_API_ROOT in .env '
        '(PC LAN IP on physical device).');
    // #region agent log
    DebugSessionLog.log(
      location: 'backend_resolver.dart:fallback',
      message: 'no backend reachable',
      hypothesisId: 'H2',
      data: {'candidatesTried': unique},
    );
    // #endregion
  }

  static String connectionHelpMessage() {
    if (!kIsWeb && Platform.isAndroid) {
      return 'Server tak nahi pahunch rahe.\n\n'
          '• Physical phone (Wi‑Fi): old_meatvo/.env mein\n'
          '  API_BASE_URL=http://YOUR_PC_IP:8080\n'
          '• USB debugging: adb reverse tcp:8080 tcp:8080\n'
          '  phir MEATVO_API_ROOT=http://127.0.0.1:8080\n'
          '• Emulator: MEATVO_API_ROOT=http://10.0.2.2:8080\n\n'
          'Backend chal raha ho: cd backend && npm run dev';
    }
    return 'Server tak nahi pahunch rahe. Backend start karein (npm run dev) '
        'aur MEATVO_API_ROOT sahi set karein.';
  }
}
