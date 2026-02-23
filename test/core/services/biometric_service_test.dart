import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_inv_app/core/services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class FakeAuthenticationOptions extends Fake implements AuthenticationOptions {}

void main() {
  late MockLocalAuthentication mockLocalAuth;

  setUpAll(() {
    registerFallbackValue(FakeAuthenticationOptions());
  });

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    BiometricService.setLocalAuthForTesting(mockLocalAuth);
    SharedPreferences.setMockInitialValues({});
  });

  group('BiometricService', () {
    group('isBiometricAvailable', () {
      test(
        'returns true when device is supported and can check biometrics',
        () async {
          when(
            () => mockLocalAuth.isDeviceSupported(),
          ).thenAnswer((_) async => true);
          when(
            () => mockLocalAuth.canCheckBiometrics,
          ).thenAnswer((_) async => true);

          final result = await BiometricService.isBiometricAvailable();

          expect(result, isTrue);
          verify(() => mockLocalAuth.isDeviceSupported()).called(1);
          verify(() => mockLocalAuth.canCheckBiometrics).called(1);
        },
      );

      test('returns false when device is not supported', () async {
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenAnswer((_) async => false);

        final result = await BiometricService.isBiometricAvailable();

        expect(result, isFalse);
        verify(() => mockLocalAuth.isDeviceSupported()).called(1);
        verifyNever(() => mockLocalAuth.canCheckBiometrics);
      });

      test('returns false when cannot check biometrics', () async {
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalAuth.canCheckBiometrics,
        ).thenAnswer((_) async => false);

        final result = await BiometricService.isBiometricAvailable();

        expect(result, isFalse);
        verify(() => mockLocalAuth.isDeviceSupported()).called(1);
        verify(() => mockLocalAuth.canCheckBiometrics).called(1);
      });

      test('returns false on PlatformException', () async {
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenThrow(PlatformException(code: 'error'));

        final result = await BiometricService.isBiometricAvailable();

        expect(result, isFalse);
      });
    });

    group('getAvailableBiometrics', () {
      test('returns list of available biometrics', () async {
        final biometrics = [BiometricType.face, BiometricType.fingerprint];
        when(
          () => mockLocalAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => biometrics);

        final result = await BiometricService.getAvailableBiometrics();

        expect(result, biometrics);
        verify(() => mockLocalAuth.getAvailableBiometrics()).called(1);
      });

      test('returns empty list on exception', () async {
        when(
          () => mockLocalAuth.getAvailableBiometrics(),
        ).thenThrow(Exception('error'));

        final result = await BiometricService.getAvailableBiometrics();

        expect(result, isEmpty);
      });
    });

    group('authenticateWithBiometrics', () {
      test('returns true when authentication is successful', () async {
        // Setup availability checks
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalAuth.canCheckBiometrics,
        ).thenAnswer((_) async => true);

        // Setup authentication
        when(
          () => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => true);

        final result = await BiometricService.authenticateWithBiometrics();

        expect(result, isTrue);
        verify(
          () => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('returns false when biometrics not available', () async {
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenAnswer((_) async => false);

        final result = await BiometricService.authenticateWithBiometrics();

        expect(result, isFalse);
        verifyNever(
          () => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          ),
        );
      });

      test('returns false upon exception', () async {
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenThrow(Exception('error'));

        final result = await BiometricService.authenticateWithBiometrics();

        expect(result, isFalse);
      });
    });

    group('Biometric preferences', () {
      test('isBiometricEnabled returns false by default', () async {
        final result = await BiometricService.isBiometricEnabled();
        expect(result, isFalse);
      });

      test('setBiometricEnabled updates preference', () async {
        await BiometricService.setBiometricEnabled(true);
        final result = await BiometricService.isBiometricEnabled();
        expect(result, isTrue);
      });
    });

    group('shouldPromptBiometric', () {
      test('returns true when enabled and available', () async {
        // Enable biometrics
        SharedPreferences.setMockInitialValues({'biometric_enabled': true});

        // Mock available
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalAuth.canCheckBiometrics,
        ).thenAnswer((_) async => true);

        final result = await BiometricService.shouldPromptBiometric();

        expect(result, isTrue);
      });

      test('returns false when disabled', () async {
        SharedPreferences.setMockInitialValues({'biometric_enabled': false});

        final result = await BiometricService.shouldPromptBiometric();

        expect(result, isFalse);
        // Should not check availability if disabled (optimization check)
        // verifyNever(() => mockLocalAuth.isDeviceSupported());
      });
    });

    group('getErrorMessage', () {
      test('returns correct message for known codes', () {
        expect(
          BiometricService.getErrorMessage(
            PlatformException(code: 'NotAvailable'),
          ),
          contains('not available'),
        );
        expect(
          BiometricService.getErrorMessage(
            PlatformException(code: 'NotEnrolled'),
          ),
          contains('No biometric credentials'),
        );
      });
    });
  });
}
