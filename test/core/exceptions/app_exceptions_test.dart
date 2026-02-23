import 'package:flutter_test/flutter_test.dart';

import 'package:mobo_inv_app/core/exceptions/app_exceptions.dart' as app_exc;

void main() {
  group('AppException base', () {
    test('toString includes type and message', () {
      final e = app_exc.UnknownException('Oops');
      expect(e.toString(), 'UnknownException: Oops');
    });
  });

  group('Concrete App exceptions store properties correctly', () {
    test('NetworkException', () {
      final cause = Exception('root');
      final e = app_exc.NetworkException('Net down', code: 'NET_1', cause: cause);
      expect(e.message, 'Net down');
      expect(e.code, 'NET_1');
      expect(e.cause, same(cause));
      expect(e.toString(), 'NetworkException: Net down');
    });

    test('ServerException', () {
      final e = app_exc.ServerException('500 error');
      expect(e.message, '500 error');
      expect(e.code, isNull);
      expect(e.cause, isNull);
      expect(e.toString(), 'ServerException: 500 error');
    });

    test('AuthException', () {
      final e = app_exc.AuthException('Unauthorized', code: '401');
      expect(e.message, 'Unauthorized');
      expect(e.code, '401');
      expect(e.toString(), 'AuthException: Unauthorized');
    });

    test('ValidationException', () {
      final e = app_exc.ValidationException('Invalid data');
      expect(e.message, 'Invalid data');
      expect(e.toString(), 'ValidationException: Invalid data');
    });

    test('UnknownException', () {
      final e = app_exc.UnknownException('Something went wrong');
      expect(e.message, 'Something went wrong');
      expect(e.toString(), 'UnknownException: Something went wrong');
    });
  });
}
