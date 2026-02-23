import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/connectivity_service.dart';
import 'package:mobo_inv_app/core/services/offline_error_handler.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  late MockConnectivityService mockConnectivity;
  late MockBuildContext mockContext;

  setUp(() {
    mockConnectivity = MockConnectivityService();
    mockContext = MockBuildContext();

    // Default internet behavior
    when(
      () => mockConnectivity.hasInternetAccess(),
    ).thenAnswer((_) async => true);

    // Inject mock
    ConnectivityService.setInstanceForTesting(mockConnectivity);
  });

  group('OfflineErrorHandler', () {
    group('retryOperation', () {
      test('succeeds immediately if operation succeeds', () async {
        final result = await OfflineErrorHandler.instance.retryOperation(
          operation: () async => 'Success',
        );
        expect(result, 'Success');
        verify(() => mockConnectivity.hasInternetAccess()).called(1);
      });

      test('retries on failure and eventually succeeds', () async {
        int attempts = 0;
        final result = await OfflineErrorHandler.instance.retryOperation(
          operation: () async {
            attempts++;
            if (attempts < 2) throw Exception('Fail');
            return 'Success';
          },
          initialDelay: const Duration(milliseconds: 1),
        );

        expect(result, 'Success');
        expect(attempts, 2);
        verify(() => mockConnectivity.hasInternetAccess()).called(2);
      });

      test('returns null (or rethrows) after max attempts', () async {
        // retryOperation rethrows if last attempt fails
        expect(
          () => OfflineErrorHandler.instance.retryOperation(
            operation: () async => throw Exception('Persist Fail'),
            maxAttempts: 2,
            initialDelay: const Duration(milliseconds: 1),
          ),
          throwsException,
        );

        verify(
          () => mockConnectivity.hasInternetAccess(),
        ).called(greaterThanOrEqualTo(1));
      });

      test('throws NoInternetException if no internet', () async {
        when(
          () => mockConnectivity.hasInternetAccess(),
        ).thenAnswer((_) async => false);

        expect(
          () => OfflineErrorHandler.instance.retryOperation(
            operation: () async => 'Should not run',
          ),
          throwsA(isA<NoInternetException>()),
        );
      });
    });

    group('handleError classification', () {
      test('returns message from NoInternetException', () {
        final error = NoInternetException('Offline');
        final msg = OfflineErrorHandler.instance.handleError(
          mockContext,
          error,
        );
        expect(msg, 'Offline');
      });

      test(
        'returns message for SocketException',
        () {
          final error = const SocketException('Connection failed');
          // SocketException toString usually contains 'SocketException'
          final msg = OfflineErrorHandler.instance.handleError(
            mockContext,
            error,
          );
          expect(msg, contains('Network error'));
        },
      ); // Note: SocketException constructor in test environment might differ slightly, but logic relies on toString or type check if implemented.
      // OfflineErrorHandler uses _isConnectivityError which checks toString for SocketException if strictly checking string.
      // Let's verify implementation:
      // if (error is NoInternetException) ...
      // ...
      // _classifyError checks toString().contains('socketexception')
    });
  });
}
