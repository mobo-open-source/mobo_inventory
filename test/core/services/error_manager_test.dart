import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_inv_app/core/services/connectivity_service.dart';
import 'package:mobo_inv_app/core/services/error_manager.dart';

void main() {
  group('ErrorManager', () {
    test('analyzeError identifies NoInternetException', () {
      final error = NoInternetException('No internet');
      final result = ErrorManager.analyzeError(error);

      expect(result.type, ErrorType.network);
      expect(result.title, 'No Internet Connection');
      expect(result.icon, Icons.wifi_off_rounded);
    });

    test('analyzeError identifies ServerUnreachableException', () {
      final error = ServerUnreachableException('Server down');
      final result = ErrorManager.analyzeError(error);

      expect(result.type, ErrorType.network);
      expect(result.title, 'Server Unreachable');
      expect(result.icon, Icons.cloud_off_rounded);
    });

    test('analyzeError identifies Authentication errors', () {
      final errors = [
        '401 Unauthorized',
        'Session Expired',
        'Odoo Session Invalid',
        'Authentication Failed',
        'odooexception: session_expired',
      ];

      for (final error in errors) {
        final result = ErrorManager.analyzeError(error);
        expect(
          result.type,
          ErrorType.authentication,
          reason: 'Failed on error: $error',
        );
        expect(result.icon, HugeIcons.strokeRoundedLockPassword);
      }
    });

    test('analyzeError identifies Access/Permission errors', () {
      final errors = [
        'Access Denied',
        'AccessError: You do not have permission',
        'Permission Denied',
      ];

      for (final error in errors) {
        final result = ErrorManager.analyzeError(error);
        expect(
          result.type,
          ErrorType.permission,
          reason: 'Failed on error: $error',
        );
        expect(result.icon, Icons.block_rounded);
      }
    });

    test('analyzeError identifies Module errors', () {
      final errors = {
        "KeyError: 'stock.picking'": 'Inventory',
        "KeyError: 'product.template'": 'Product',
        "KeyError: 'mrp.production'": 'Manufacturing',
        "KeyError: 'sale.order'": 'Sales',
        "KeyError: 'purchase.order'": 'Purchase',
        "KeyError: 'account.move'": 'Accounting',
        "KeyError: 'hr.employee'": 'HR',
        "KeyError: 'res.partner'": 'Contacts',
        "Data model 'stock.move' not available":
            'Inventory', // Generic parsing fallback
        "stock.picking model not found": 'Inventory',
        "Module stock is not installed": 'Inventory',
      };

      errors.forEach((errorStr, expectedModule) {
        final result = ErrorManager.analyzeError(errorStr);
        expect(
          result.type,
          ErrorType.moduleNotInstalled,
          reason: 'Failed on error: $errorStr',
        );
        expect(
          result.moduleName,
          expectedModule,
          reason: 'Wrong module for: $errorStr',
        );
        expect(result.icon, Icons.extension_off_rounded);
      });
    });

    test('analyzeError falls back to Server Error', () {
      final error = 'Some random error occurred';
      final result = ErrorManager.analyzeError(error);

      expect(result.type, ErrorType.server);
      expect(result.title, 'Server Error');
      expect(result.icon, Icons.error_outline_rounded);
    });

    test(
      'analyzeError falls back to default mapping using OdooErrorMapper',
      () {
        // OdooErrorMapper also maps 404 to "Server resource not found"
        final error = '404 Not Found';
        final result = ErrorManager.analyzeError(error);

        // Note: ErrorManager checks module error regex for 404 stock/product
        // If just 404, it might go to server error with mapper message
        expect(result.type, ErrorType.server);
        expect(result.message, contains('Server resource not found'));
      },
    );
  });
}
