import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';
import 'package:mobo_inv_app/core/services/odoo_metadata_service.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOdooClient extends Mock implements OdooClient {}

void main() {
  late MockOdooClient mockClient;
  late AppSessionData dummySession;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockOdooClient();
    SharedPreferences.setMockInitialValues({});

    final odooSession = OdooSession(
      id: 'test_session',
      userId: 1,
      partnerId: 1,
      companyId: 1,
      allowedCompanies: [],
      userLogin: 'admin',
      userName: 'Admin',
      userLang: 'en_US',
      userTz: 'UTC',
      isSystem: true,
      dbName: 'test_db',
      serverVersion: '16.0',
    );

    dummySession = AppSessionData(
      odooSession: odooSession,
      password: 'password',
      serverUrl: 'https://test.odoo.com',
      database: 'test_db',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    OdooSessionManager.setClientForTesting(mockClient);
    OdooSessionManager.setSessionForTesting(dummySession);
    OdooMetadataService.reset();
  });

  tearDown(() {
    OdooSessionManager.resetForTesting();
    OdooMetadataService.reset();
  });

  group('OdooMetadataService', () {
    test('hasModel returns true when ir.model search succeeds', () async {
      when(() => mockClient.callKw(any())).thenAnswer((invocation) async {
        final payload = invocation.positionalArguments.first as Map;
        if (payload['model'] == 'ir.model' &&
            payload['method'] == 'search_count') {
          return 1;
        }
        return 0;
      });

      final result = await OdooMetadataService.hasModel('test.model');
      expect(result, isTrue);
      verify(() => mockClient.callKw(any())).called(1);
    });

    test('hasModel returns false when ir.model search returns 0', () async {
      when(() => mockClient.callKw(any())).thenAnswer((_) async => 0);

      final result = await OdooMetadataService.hasModel('test.model');
      expect(result, isFalse);
    });

    test('hasModel falls back to fields_get on exception', () async {
      // First call throws
      when(() => mockClient.callKw(any())).thenAnswer((invocation) async {
        final payload = invocation.positionalArguments.first as Map;

        if (payload['model'] == 'ir.model') {
          throw Exception('Access Denied to ir.model');
        }

        if (payload['method'] == 'fields_get' &&
            payload['model'] == 'test.fallback') {
          return {'field1': {}};
        }
        return {};
      });

      final result = await OdooMetadataService.hasModel('test.fallback');

      expect(result, isTrue);
      // Verify called twice (once for ir.model, once for fields_get)
      verify(() => mockClient.callKw(any())).called(2);
    });

    test('hasModel returns false if fallback also fails', () async {
      when(() => mockClient.callKw(any())).thenThrow(Exception('Both failed'));

      final result = await OdooMetadataService.hasModel('test.fail');

      expect(result, isFalse);
    });

    test('hasModel uses cache', () async {
      when(() => mockClient.callKw(any())).thenAnswer((_) async => 1);

      // First call
      await OdooMetadataService.hasModel('test.cache');

      clearInteractions(mockClient);

      // Second call
      final result = await OdooMetadataService.hasModel('test.cache');

      expect(result, isTrue);
      verifyNever(() => mockClient.callKw(any()));
    });
  });
}
