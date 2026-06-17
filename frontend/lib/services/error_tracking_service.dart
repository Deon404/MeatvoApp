import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/env_config.dart';

/// Error tracking service using Sentry
/// Provides centralized error logging and tracking
class ErrorTrackingService {
  static void _configureOptions(SentryFlutterOptions options) {
    options.dsn = EnvConfig.sentryDsn;
    options.environment = EnvConfig.appEnv;
    options.tracesSampleRate = EnvConfig.isProduction
        ? EnvConfig.sentryTracesSampleRate
        : 1.0;
    options.release = 'meatvo_official@1.0.0';
    options.debug = EnvConfig.isDevelopment;
    options.maxBreadcrumbs = 100;
    options.enableAutoPerformanceTracing = true;
    options.enableUserInteractionTracing = true;
    options.sendDefaultPii = true;
  }

  /// Wraps [runApp] with [SentryFlutter.init] when [SENTRY_DSN] is configured.
  static Future<void> runApp(VoidCallback appRunner) async {
    final dsn = EnvConfig.sentryDsn;

    if (dsn.isEmpty) {
      debugPrint('⚠️ Sentry DSN not found. Error tracking disabled.');
      appRunner();
      return;
    }

    await SentryFlutter.init(
      _configureOptions,
      appRunner: appRunner,
    );

    debugPrint('✅ Sentry initialized successfully');
  }

  /// Capture an exception
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Map<String, dynamic>? context,
    String? tag,
  }) async {
    if (EnvConfig.sentryDsn.isEmpty) {
      debugPrint('Error (Sentry not configured): $exception');
      return;
    }

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: Hint.withMap(context ?? {}),
      withScope: (scope) {
        if (tag != null) {
          scope.setTag('error_type', tag);
        }
        scope.setContexts('app', {
          'environment': EnvConfig.appEnv,
        });
      },
    );
  }

  /// Capture a message (non-exception error)
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.error,
    Map<String, dynamic>? context,
    String? tag,
  }) async {
    if (EnvConfig.sentryDsn.isEmpty) {
      debugPrint('Message (Sentry not configured): $message');
      return;
    }

    await Sentry.captureMessage(
      message,
      level: level,
      hint: Hint.withMap(context ?? {}),
      withScope: (scope) {
        if (tag != null) {
          scope.setTag('message_type', tag);
        }
        scope.setContexts('app', {
          'environment': EnvConfig.appEnv,
        });
      },
    );
  }

  /// Set user context for error tracking
  static Future<void> setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) async {
    if (EnvConfig.sentryDsn.isEmpty) return;

    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: data,
      ));
    });
  }

  /// Clear user context
  static Future<void> clearUser() async {
    if (EnvConfig.sentryDsn.isEmpty) return;

    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Add breadcrumb for debugging
  static void addBreadcrumb(
    String message, {
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    if (EnvConfig.sentryDsn.isEmpty) return;

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Set additional context
  static Future<void> setContext(
    String key,
    Map<String, dynamic> context,
  ) async {
    if (EnvConfig.sentryDsn.isEmpty) return;

    await Sentry.configureScope((scope) {
      scope.setContexts(key, context);
    });
  }

  /// Set tag for filtering errors
  static Future<void> setTag(String key, String value) async {
    if (EnvConfig.sentryDsn.isEmpty) return;

    await Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }
}
