import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';
import 'package:mobo_inv_app/features/company/providers/company_provider.dart';
import 'package:mobo_inv_app/features/company/data/company_local_datasource.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';

// Mocks
class MockCompanyLocalDataSource extends Mock
    implements CompanyLocalDataSource {}

class MockOdooClient extends Mock implements OdooClient {}

class MockOdooSession extends Mock implements OdooSession {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CompanyProvider provider;
  late MockCompanyLocalDataSource mockLocalDataSource;
  late MockOdooClient mockOdooClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OdooSessionManager.resetForTesting();

    mockLocalDataSource = MockCompanyLocalDataSource();
    mockOdooClient = MockOdooClient();

    // Default mock behaviors
    when(
      () => mockLocalDataSource.getAllCompanies(),
    ).thenAnswer((_) async => []);
    when(
      () => mockLocalDataSource.putAllCompanies(any()),
    ).thenAnswer((_) async {});
    when(() => mockLocalDataSource.clear()).thenAnswer((_) async {});

    provider = CompanyProvider(localDataSource: mockLocalDataSource);
  });

  group('CompanyProvider Tests', () {
    test('initial state should be valid', () {
      expect(provider.companies, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('initialize should load from local when offline/no-session', () async {
      // Arrange
      final localCompanies = [
        {'id': 1, 'name': 'Company A'},
        {'id': 2, 'name': 'Company B'},
      ];
      when(
        () => mockLocalDataSource.getAllCompanies(),
      ).thenAnswer((_) async => localCompanies);

      // Act
      await provider.initialize();

      // Assert
      expect(provider.companies, equals(localCompanies));
      expect(provider.isLoading, isFalse);
      verify(() => mockLocalDataSource.getAllCompanies()).called(1);
    });

    test('initialize should fetch from server when session active', () async {
      // Arrange
      // Mock isSessionValid to return true by default
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'sessionId': 'sess_123',
        'userLogin': 'admin',
        'database': 'test_db',
        'serverUrl': 'https://test.com',
        'userId': 1,
      });
      // Add secure storage mock for password
      FlutterSecureStorage.setMockInitialValues({});
      await SecureStorageService.instance.storePassword(
        'session_password_username_admin',
        'password',
      );

      OdooSessionManager.setClientForTesting(mockOdooClient);

      // Also set session for testing
      final odooSession = OdooSession(
        id: 'sess_123',
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
      OdooSessionManager.setSessionForTesting(
        AppSessionData(
          odooSession: odooSession,
          password: 'password',
          serverUrl: 'https://test.com',
          database: 'test_db',
        ),
      );

      // Mock user companies fetch
      when(() => mockOdooClient.callKw(any())).thenAnswer((invocation) async {
        final args = invocation.positionalArguments[0] as Map;
        if (args['model'] == 'res.users') {
          return [
            {
              'company_ids': [1, 2],
              'company_id': [1, 'Company A'],
            },
          ];
        } else if (args['model'] == 'res.company') {
          return [
            {'id': 1, 'name': 'Company A'},
            {'id': 2, 'name': 'Company B'},
          ];
        }
        return [];
      });

      // Act
      await provider.initialize();

      // Assert
      expect(provider.companies.length, 2);
      expect(provider.companies[0]['name'], 'Company A');
      // Should save to local
      verify(() => mockLocalDataSource.putAllCompanies(any())).called(1);
    });
  });
}
