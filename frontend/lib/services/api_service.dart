import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});

class RealtimeChannel {
  final void Function()? _onSubscribe;

  RealtimeChannel({void Function()? onSubscribe}) : _onSubscribe = onSubscribe;

  RealtimeChannel subscribe() {
    _onSubscribe?.call();
    return this;
  }

  Future<String> unsubscribe() async => 'ok';
}

class ApiService {
  final Ref? _ref;
  late final ApiClient _client;

  ApiService([this._ref]) {
    _client = _ref?.read(apiClientProvider) ?? ApiClient();
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _client.dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data, Options? options}) =>
      _client.dio.post(path, data: data, options: options);

  Future<Response> put(String path, {dynamic data}) =>
      _client.dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _client.dio.patch(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _client.dio.delete(path, data: data);

  Future<Response> postMultipart(String path, FormData data) =>
      _client.dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );
}
