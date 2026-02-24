
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  AppException(this.message, {this.code, this.cause});
  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  NetworkException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class ServerException extends AppException {
  ServerException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class AuthException extends AppException {
  AuthException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class ValidationException extends AppException {
  ValidationException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}

class UnknownException extends AppException {
  UnknownException(String message, {String? code, Object? cause})
      : super(message, code: code, cause: cause);
}
