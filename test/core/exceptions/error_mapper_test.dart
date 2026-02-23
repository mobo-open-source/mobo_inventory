import 'package:flutter_test/flutter_test.dart';

import 'package:mobo_inv_app/core/exceptions/app_exceptions.dart' as app_exc;
import 'package:mobo_inv_app/core/exceptions/error_mapper.dart';
import 'package:mobo_inv_app/core/services/connectivity_service.dart';

void main() {
  group('ErrorMapper.toAppException', () {
    test('maps NoInternetException to App NetworkException with cause', () {
      final original = NoInternetException('No internet');
      final mapped = ErrorMapper.toAppException(original);
      expect(mapped, isA<app_exc.NetworkException>());
      expect(mapped.message, 'No internet');
      expect(mapped.cause, same(original));
    });

    test('maps ServerUnreachableException to App ServerException with cause', () {
      final original = ServerUnreachableException('Server down');
      final mapped = ErrorMapper.toAppException(original);
      expect(mapped, isA<app_exc.ServerException>());
      expect(mapped.message, 'Server down');
      expect(mapped.cause, same(original));
    });

    test('maps Session expired and Unauthorized to AuthException with friendly message', () {
      final mapped1 = ErrorMapper.toAppException(Exception('Session expired: token invalid'));
      expect(mapped1, isA<app_exc.AuthException>());
      expect(mapped1.message, 'Your session has expired. Please log in again.');

      final mapped2 = ErrorMapper.toAppException(Exception('Unauthorized access'));
      expect(mapped2, isA<app_exc.AuthException>());
      expect(mapped2.message, 'Your session has expired. Please log in again.');
    });

    test('maps SocketException or Connection refused to NetworkException with generic message', () {
      final mapped1 = ErrorMapper.toAppException(Exception('SocketException: failed host lookup'));
      expect(mapped1, isA<app_exc.NetworkException>());
      expect(mapped1.message, 'Network error occurred. Please check your internet connection.');

      final mapped2 = ErrorMapper.toAppException(Exception('Connection refused by host'));
      expect(mapped2, isA<app_exc.NetworkException>());
      expect(mapped2.message, 'Network error occurred. Please check your internet connection.');
    });

    test('maps unknown errors to UnknownException with generic message and preserves cause', () {
      final original = StateError('unexpected');
      final mapped = ErrorMapper.toAppException(original);
      expect(mapped, isA<app_exc.UnknownException>());
      expect(mapped.message, 'Something went wrong. Please try again.');
      expect(mapped.cause, same(original));
    });
  });
}
