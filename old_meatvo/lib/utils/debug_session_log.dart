import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Debug-session NDJSON logger (session 80935b).
class DebugSessionLog {
  DebugSessionLog._();

  static const _endpoint =
      'http://127.0.0.1:7369/ingest/6751d64c-c555-4b18-b586-d89be303c010';
  static const _sessionId = '80935b';

  static void log({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, Object?> data = const {},
    String runId = 'pre-fix',
  }) {
    final payload = <String, Object?>{
      'sessionId': _sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // #region agent log
    debugPrint('[DEBUG-80935b][$hypothesisId] $message ${jsonEncode(data)}');
    if (kIsWeb) return;
    () async {
      try {
        final client = HttpClient();
        final req = await client.postUrl(Uri.parse(_endpoint));
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('X-Debug-Session-Id', _sessionId);
        req.write(jsonEncode(payload));
        await req.close();
        client.close(force: true);
      } catch (_) {}
    }();
    // #endregion
  }
}
