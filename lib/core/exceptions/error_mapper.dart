import '../services/connectivity_service.dart';
import 'app_exceptions.dart';
import 'dart:io';
import 'dart:async';

class ErrorMapper {
  static AppException toAppException(Object error, [StackTrace? stack]) {

    if (error is NoInternetException) {
      return NetworkException(error.message, cause: error);
    }
    if (error is ServerUnreachableException) {
      return ServerException(error.message, cause: error);
    }

    if (error is SocketException) {
      if (error.message.contains('Failed host lookup')) {
        return ServerException(
          'Cannot reach server. Please check the server URL and your internet connection.',
          cause: error,
        );
      }
      return NetworkException(
        'Network connection failed. Please check your internet connection.',
        cause: error,
      );
    }

    if (error is TimeoutException) {
      return NetworkException(
        'Connection timed out. Please check your internet connection and try again.',
        cause: error,
      );
    }

    final msg = error.toString();
    if (msg.contains('Session expired') || msg.contains('Unauthorized')) {
      return AuthException(
        'Your session has expired. Please log in again.',
        cause: error,
      );
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return NetworkException(
        'Network error occurred. Please check your internet connection.',
        cause: error,
      );
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return NetworkException(
        'Connection timed out. Please try again.',
        cause: error,
      );
    }

    return UnknownException(
      'Something went wrong. Please try again.',
      cause: error,
    );
  }
}
