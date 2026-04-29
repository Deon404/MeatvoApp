import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'storage_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});

class ApiService {
  final Ref _ref;
  late final Dio _dio;

  ApiService(this._ref) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_ref, _dio));
  }

  Future<Response<dynamic>> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }
}

class _AuthInterceptor extends Interceptor {
  final Ref _ref;
  final Dio _dio;

  _AuthInterceptor(this._ref, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _ref.read(storageServiceProvider).getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    if (!is401) {
      handler.next(err);
      return;
    }

    try {
      final storage = _ref.read(storageServiceProvider);
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        handler.next(err);
        return;
      }

      final refreshResponse = await _dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      final payload = refreshResponse.data as Map<String, dynamic>;
      final data = (payload['data'] ?? payload) as Map<String, dynamic>;
      final newAccess = (data['accessToken'] ?? data['token'] ?? '').toString();
      final newRefresh = (data['refreshToken'] ?? refreshToken).toString();

      if (newAccess.isEmpty) {
        handler.next(err);
        return;
      }

      await storage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer $newAccess';
      final retry = await _dio.fetch(request);
      handler.resolve(retry);
    } catch (_) {
      await _ref.read(storageServiceProvider).clear();
      handler.next(err);
    }
  }
}
