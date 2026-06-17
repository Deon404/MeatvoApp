import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../config/backend_resolver.dart';
import '../utils/session_expired.dart';
import 'storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(storageServiceProvider));
});

class ApiClient {
  ApiClient([StorageService? storageService])
      : _storage = storageService ?? StorageService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      );
    }
  }

  late final Dio _dio;
  final StorageService _storage;
  static const String _retryAttemptKey = 'timeout_retry_attempt';
  static const String _rateLimitRetryKey = 'rate_limit_retry_attempt';

  Dio get dio => _dio;

  static Completer<void>? _refreshCompleter;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!BackendResolver.hasReachableBackend) {
      await BackendResolver.ensureReachable();
    }
    if (!BackendResolver.hasReachableBackend) {
      BackendResolver.logConnectionDevHint();
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: BackendResolver.connectionUserMessage(),
        ),
      );
      return;
    }
    _dio.options.baseUrl = ApiConfig.baseUrl;
    final token = await _storage.getAccessToken();
    if (token?.isNotEmpty == true) {
      options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        debugPrint('[ApiClient] Request to ${options.path} with auth token');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[ApiClient] Request to ${options.path} WITHOUT auth token');
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (await _retryRateLimitRequest(err, handler)) {
      return;
    }

    if (await _retryConnectionRequest(err, handler)) {
      return;
    }

    if (await _retryTimeoutRequest(err, handler)) {
      return;
    }

    if (err.response?.statusCode != 401 || _isAuthExempt(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    if (_refreshCompleter != null) {
      try {
        await _refreshCompleter!.future;
        final retry = await _retryRequest(err.requestOptions);
        handler.resolve(retry);
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    _refreshCompleter = Completer<void>();

    try {
      await _refreshAccessToken();
      _refreshCompleter?.complete();
      debugPrint('[ApiClient] Token refresh successful, retrying request');
      final retry = await _retryRequest(err.requestOptions);
      handler.resolve(retry);
    } catch (error, stackTrace) {
      debugPrint('[ApiClient] Token refresh failed: $error');
      debugPrint('[ApiClient] Clearing all storage and notifying session expired');
      if (!(_refreshCompleter?.isCompleted ?? true)) {
        _refreshCompleter?.completeError(error, stackTrace);
      }
      await _storage.clear();
      notifySessionExpired();
      handler.next(err);
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _retryRateLimitRequest(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 429) {
      return false;
    }

    final attempts = (err.requestOptions.extra[_rateLimitRetryKey] as int?) ?? 0;
    if (attempts >= 2) {
      return false;
    }

    final retryAfterHeader = err.response?.headers.value('retry-after');
    final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '') ?? 2;
    await Future<void>.delayed(
      Duration(seconds: retryAfterSeconds.clamp(1, 5)),
    );

    final nextExtra = Map<String, dynamic>.from(err.requestOptions.extra)
      ..[_rateLimitRetryKey] = attempts + 1;

    try {
      final retryResponse = await _dio.fetch<dynamic>(
        err.requestOptions.copyWith(extra: nextExtra),
      );
      handler.resolve(retryResponse);
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  Future<bool> _retryConnectionRequest(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.type != DioExceptionType.connectionError) {
      return false;
    }

    const retryKey = 'connection_reprobe_attempt';
    final attempts = (err.requestOptions.extra[retryKey] as int?) ?? 0;
    if (attempts >= 1) {
      return false;
    }

    await BackendResolver.init();
    if (!BackendResolver.hasReachableBackend) {
      return false;
    }

    _dio.options.baseUrl = ApiConfig.baseUrl;
    final nextExtra = Map<String, dynamic>.from(err.requestOptions.extra)
      ..[retryKey] = attempts + 1;

    try {
      final retryResponse = await _dio.fetch<dynamic>(
        err.requestOptions.copyWith(
          extra: nextExtra,
          baseUrl: ApiConfig.baseUrl,
        ),
      );
      handler.resolve(retryResponse);
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  Future<bool> _retryTimeoutRequest(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isTimeoutError(err)) {
      return false;
    }

    final attempts = (err.requestOptions.extra[_retryAttemptKey] as int?) ?? 0;
    if (attempts >= ApiConfig.retryAttempts) {
      return false;
    }

    final nextExtra = Map<String, dynamic>.from(err.requestOptions.extra)
      ..[_retryAttemptKey] = attempts + 1;

    try {
      final retryResponse = await _dio.fetch<dynamic>(
        err.requestOptions.copyWith(extra: nextExtra),
      );
      handler.resolve(retryResponse);
      return true;
    } on DioException catch (_) {
      return false;
    }
  }

  bool _isTimeoutError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;
  }

  bool _isAuthExempt(String path) {
    return path == ApiAuthPaths.sendOtp ||
        path == ApiAuthPaths.verifyOtp ||
        path == ApiAuthPaths.refresh ||
        path == ApiAuthPaths.refreshToken ||
        path.endsWith(ApiAuthPaths.sendOtp) ||
        path.endsWith(ApiAuthPaths.verifyOtp) ||
        path.endsWith(ApiAuthPaths.refresh) ||
        path.endsWith(ApiAuthPaths.refreshToken);
  }

  Future<void> _refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    debugPrint('[ApiClient] Attempting token refresh - Refresh token available: ${refreshToken != null && refreshToken.isNotEmpty}');
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('[ApiClient] ERROR: Refresh token is missing from secure storage!');
      throw StateError('Refresh token unavailable');
    }

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        contentType: Headers.jsonContentType,
      ),
    );

    debugPrint('[ApiClient] Sending refresh token request to ${ApiAuthPaths.refresh}');
    final response = await refreshDio.post<Map<String, dynamic>>(
      ApiAuthPaths.refresh,
      data: {'refreshToken': refreshToken},
    );

    debugPrint('[ApiClient] Refresh response received: ${response.statusCode}');
    final raw = response.data ?? const <String, dynamic>{};
    final payload = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    final accessToken =
        (payload['accessToken'] ?? payload['token'] ?? '').toString().trim();
    final nextRefreshToken =
        (payload['refreshToken'] ?? refreshToken).toString().trim();

    if (accessToken.isEmpty) {
      debugPrint('[ApiClient] ERROR: Refresh response missing access token!');
      throw StateError('Refresh response missing access token');
    }

    debugPrint('[ApiClient] Saving refreshed tokens');
    await _storage.saveTokens(accessToken, nextRefreshToken);
    debugPrint('[ApiClient] Refresh complete');
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
    final token = await _storage.getAccessToken();
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (token?.isNotEmpty == true) {
      headers['Authorization'] = 'Bearer $token';
    }

    return _dio.fetch<dynamic>(
      requestOptions.copyWith(
        headers: headers,
      ),
    );
  }
}
