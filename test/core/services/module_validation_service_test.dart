import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';
import 'package:mobo_inv_app/core/services/module_validation_service.dart';
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

    // Create dummy session
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

    // Inject into OdooSessionManager
    OdooSessionManager.setClientForTesting(mockClient);
    OdooSessionManager.setSessionForTesting(dummySession);

    // Mock isSessionValid to return true by default
    SharedPreferences.setMockInitialValues({'isLoggedIn': true});

    // Clear cache in service
    ModuleValidationService.instance.clearCache();
  });

  tearDown(() {
    OdooSessionManager.resetForTesting();
  });

  group('ModuleValidationService', () {
    test(
      'validateRequiredModules returns true for installed modules',
      () async {
        // Mock callKw for stock and product checks
        when(() => mockClient.callKw(any())).thenAnswer((invocation) async {
          final args = invocation.positionalArguments.first as Map;
          final domain = (args['args'] as List).first as List;
          final moduleName = domain.first[2] as String;

          if (moduleName == 'stock' || moduleName == 'product') {
            return 1; // Installed count > 0
          }
          return 0;
        });

        final result = await ModuleValidationService.instance
            .validateRequiredModules(forceRefresh: true);

        expect(result['stock'], isTrue);
        expect(result['product'], isTrue);
        verify(() => mockClient.callKw(any())).called(2);
      },
    );

    test('validateRequiredModules handles missing modules', () async {
      // Mock: stock installed, product missing
      when(() => mockClient.callKw(any())).thenAnswer((invocation) async {
        final args = invocation.positionalArguments.first as Map;
        final domain = (args['args'] as List).first as List;
        final moduleName = domain.first[2] as String;

        if (moduleName == 'stock') return 1;
        return 0;
      });

      final result = await ModuleValidationService.instance
          .validateRequiredModules(forceRefresh: true);

      expect(result['stock'], isTrue);
      expect(result['product'], isFalse);
    });

    test('validateRequiredModules returns cached results', () async {
      // First call to populate cache
      when(() => mockClient.callKw(any())).thenAnswer((_) async => 1);
      await ModuleValidationService.instance.validateRequiredModules(
        forceRefresh: true,
      );

      clearInteractions(mockClient);

      // Second call should use cache
      final result = await ModuleValidationService.instance
          .validateRequiredModules(forceRefresh: false);

      expect(result['stock'], isTrue);
      verifyNever(() => mockClient.callKw(any()));
    });

    test('isInventoryInstalled helper works', () async {
      when(() => mockClient.callKw(any())).thenAnswer((_) async => 1);
      final result = await ModuleValidationService.instance
          .isInventoryInstalled(forceRefresh: true);
      expect(result, isTrue);
    });

    test('getMissingModulesMessage generates correct message', () {
      var msg = ModuleValidationService.instance.getMissingModulesMessage({
        'stock': true,
        'product': true,
      });
      expect(msg, isEmpty);

      msg = ModuleValidationService.instance.getMissingModulesMessage({
        'stock': false,
        'product': true,
      });
      expect(msg, contains('Inventory (stock)'));

      msg = ModuleValidationService.instance.getMissingModulesMessage({
        'stock': false,
        'product': false,
      });
      expect(msg, contains('Inventory (stock), Product'));
    });

    test('Returns false for modules on client error', () async {
      when(() => mockClient.callKw(any())).thenThrow(Exception('RPC Error'));

      final result = await ModuleValidationService.instance
          .validateRequiredModules(forceRefresh: true);

      expect(result['stock'], isFalse);
      expect(result['product'], isFalse);
    });

    test('Returns empty map when session is unavailable', () async {
      OdooSessionManager.setSessionForTesting(null);
      OdooSessionManager.setClientForTesting(null);
      SharedPreferences.setMockInitialValues({'isLoggedIn': false});

      final result = await ModuleValidationService.instance
          .validateRequiredModules(forceRefresh: true);

      expect(result, isEmpty);
    });
  });
}
