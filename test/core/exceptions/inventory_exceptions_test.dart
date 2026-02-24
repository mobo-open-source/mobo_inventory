import 'package:flutter_test/flutter_test.dart';

import 'package:mobo_inv_app/core/exceptions/inventory_exceptions.dart';

void main() {
  group('InventoryException base', () {
    test('toString contains message', () {
      // Use a simple subclass to test base toString
      final e = ValidationException('internal message', 'User friendly');
      expect(e.toString(), 'ValidationException: User friendly');
    });
  });

  group('NetworkException', () {
    test('stores fields and formats toString', () {
      final e = NetworkException(
        'Timeout',
        NetworkErrorType.connectionTimeout,
        code: 'TIMEOUT',
        details: {'retryAfter': 3},
      );
      expect(e.message, 'Timeout');
      expect(e.code, 'TIMEOUT');
      expect(e.details, containsPair('retryAfter', 3));
      expect(
        e.toString(),
        'NetworkException(connectionTimeout): Timeout',
      );
    });
  });

  group('ValidationException', () {
    test('with field specified', () {
      final e = ValidationException(
        'Invalid quantity',
        'Please enter a value greater than 0',
        field: 'qty',
        code: 'VAL_1',
      );
      expect(e.field, 'qty');
      expect(e.userMessage, 'Please enter a value greater than 0');
      expect(
        e.toString(),
        'ValidationException(qty): Please enter a value greater than 0',
      );
    });

    test('without field specified', () {
      final e = ValidationException('Bad', 'Oops');
      expect(e.field, isNull);
      expect(e.toString(), 'ValidationException: Oops');
    });
  });

  group('SyncException', () {
    test('formats toString with enum value', () {
      final e = SyncException('Conflict', SyncErrorType.statusConflict);
      expect(e.toString(), 'SyncException(statusConflict): Conflict');
    });
  });

  group('OdooApiException', () {
    test('includes status code and endpoint in toString', () {
      final e = OdooApiException('Not Found', 404, endpoint: '/api/products');
      expect(e.statusCode, 404);
      expect(e.endpoint, '/api/products');
      expect(
        e.toString(),
        'OdooApiException(404 - /api/products): Not Found',
      );
    });

    test('without endpoint', () {
      final e = OdooApiException('Bad Request', 400);
      expect(e.toString(), 'OdooApiException(400): Bad Request');
    });
  });

  group('BusinessRuleException', () {
    test('toString includes rule', () {
      final e = BusinessRuleException('Cannot transfer to same location', 'different_source_dest');
      expect(e.rule, 'different_source_dest');
      expect(
        e.toString(),
        'BusinessRuleException(different_source_dest): Cannot transfer to same location',
      );
    });
  });

  group('PermissionException', () {
    test('toString includes operation', () {
      final e = PermissionException('Not allowed', 'delete');
      expect(e.operation, 'delete');
      expect(e.toString(), 'PermissionException(delete): Not allowed');
    });
  });

  group('DataNotFoundException', () {
    test('with resourceId', () {
      final e = DataNotFoundException('Product not found', 'product', resourceId: 42);
      expect(e.resourceType, 'product');
      expect(e.resourceId, 42);
      expect(e.toString(), 'DataNotFoundException(product #42): Product not found');
    });

    test('without resourceId', () {
      final e = DataNotFoundException('Picking not found', 'stock.picking');
      expect(e.resourceType, 'stock.picking');
      expect(e.resourceId, isNull);
      expect(e.toString(), 'DataNotFoundException(stock.picking): Picking not found');
    });
  });
}
