import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/biometric_context_service.dart';

void main() {
  group('BiometricContextService', () {
    test('start and end account operations toggle state', () {
      final svc = BiometricContextService();
      svc.reset();

      expect(svc.isAccountOperation, isFalse);
      expect(svc.shouldSkipBiometric, isFalse);

      svc.startAccountOperation('login');
      expect(svc.isAccountOperation, isTrue);
      expect(svc.activeOperations, contains('login'));
      expect(svc.shouldSkipBiometric, isTrue);

      svc.endAccountOperation('login');
      expect(svc.isAccountOperation, isFalse);
      // Immediately after end, grace period should still skip
      expect(svc.shouldSkipBiometric, isTrue);
    });

    test('grace period elapses and shouldSkipBiometric becomes false', () async {
      final svc = BiometricContextService();
      svc.reset();

      svc.startAccountOperation('switch');
      svc.endAccountOperation('switch');

      // wait just over 3 seconds to exceed the grace period (3s)
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(svc.shouldSkipBiometric, isFalse);
    });

    test('reset clears all internal state', () {
      final svc = BiometricContextService();
      svc.reset();
      svc.startAccountOperation('logout');
      expect(svc.isAccountOperation, isTrue);
      svc.reset();
      expect(svc.isAccountOperation, isFalse);
      expect(svc.activeOperations, isEmpty);
      expect(svc.shouldSkipBiometric, isFalse);
    });
  });
}
