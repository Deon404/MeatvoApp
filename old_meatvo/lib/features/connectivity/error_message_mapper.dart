import 'package:dio/dio.dart';

import '../../constants/home_strings.dart';

/// Maps errors to user-safe copy — never expose DioException on UI.
abstract final class ErrorMessageMapper {
  static String userMessage(Object error, {String? fallback}) {
    if (error is DioException) {
      return HomeStrings.connectionLostMessage;
    }
    return fallback ?? HomeStrings.genericHomeLoadError;
  }

  static bool isConnectionError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    return false;
  }
}
