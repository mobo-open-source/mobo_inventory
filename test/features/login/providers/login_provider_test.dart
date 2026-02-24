import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_inv_app/features/login/providers/login_provider.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mobo_inv_app/core/services/session_service.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';
import 'package:mobo_inv_app/core/services/connectivity_service.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:mobo_inv_app/core/services/database_service.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockOdooClient extends Mock implements OdooClient {}

class MockOdooSession extends Mock implements OdooSession {}

class MockFormKey extends Mock implements GlobalKey<FormState> {}

class MockFormState extends Mock implements FormState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      super.toString();
}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  late MockSecureStorageService mockSecureStorage;
  late MockConnectivityService mockConnectivity;
  late MockOdooClient mockOdooClient;
  late MockDatabaseService mockDatabaseService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage = MockSecureStorageService();
    mockConnectivity = MockConnectivityService();
    mockOdooClient = MockOdooClient();
    mockDatabaseService = MockDatabaseService();

    SecureStorageService.setInstanceForTesting(mockSecureStorage);
    ConnectivityService.setInstanceForTesting(mockConnectivity);

    OdooSessionManager.resetForTesting();
    SessionService.instance.resetForTesting();
  });

  group('LoginProvider', () {
    test('initial state is correct', () {
      final provider = LoginProvider();
      expect(provider.isLoading, isFalse);
      expect(provider.isLoadingDatabases, isFalse);
      expect(provider.urlCheck, isFalse);
      expect(provider.database, isNull);
      expect(provider.errorMessage, isNull);
    });

    test('isValidUrl validates URLs correctly', () {
      final provider = LoginProvider();
      expect(provider.isValidUrl('test.com'), isTrue);
      expect(provider.isValidUrl('http://test.com'), isTrue);
      expect(provider.isValidUrl('https://test.com'), isTrue);
      expect(provider.isValidUrl(''), isFalse);
      expect(provider.isValidUrl('!!!'), isFalse);
    });

    test('fetchDatabaseList success', () async {
      when(
        () => mockDatabaseService.fetchDatabaseList(any()),
      ).thenAnswer((_) async => ['db1', 'db2']);

      final provider = LoginProvider(
        clientFactory: (_) => mockOdooClient,
        databaseService: mockDatabaseService,
      );
      provider.urlController.text = 'test.com';

      await provider.fetchDatabaseList();

      expect(provider.urlCheck, isTrue);
      expect(provider.dropdownItems, ['db1', 'db2']);
      expect(provider.database, 'db1');
    });

    test('login success', () async {
      final mockSession = MockOdooSession();
      when(() => mockSession.id).thenReturn('session_id');
      when(() => mockSession.userId).thenReturn(1);
      when(() => mockSession.partnerId).thenReturn(1);
      when(() => mockSession.companyId).thenReturn(1);
      when(() => mockSession.userName).thenReturn('Test User');
      when(() => mockSession.userLogin).thenReturn('test@test.com');
      when(() => mockSession.dbName).thenReturn('test_db');
      when(() => mockSession.userLang).thenReturn('en_US');
      when(() => mockSession.userTz).thenReturn('UTC');
      when(() => mockSession.isSystem).thenReturn(false);
      when(() => mockSession.serverVersion).thenReturn('16.0');
      when(() => mockSession.allowedCompanies).thenReturn([]);

      final appSession = AppSessionData(
        odooSession: mockSession,
        password: 'password',
        serverUrl: 'https://test.com',
        database: 'test_db',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      OdooSessionManager.setAuthenticateForTesting(
        ({
          required String serverUrl,
          required String database,
          required String username,
          required String password,
        }) async => appSession,
      );

      when(
        () => mockConnectivity.ensureInternetOrThrow(),
      ).thenAnswer((_) async => null);
      when(
        () => mockConnectivity.ensureServerReachable(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockSecureStorage.storePassword(any(), any()),
      ).thenAnswer((_) async {});

      final provider = LoginProvider();

      // Mock form validation
      final mockFormKey = MockFormKey();
      final mockFormState = MockFormState();
      when(() => mockFormKey.currentState).thenReturn(mockFormState);
      when(() => mockFormState.validate()).thenReturn(true);
      provider.formKey = mockFormKey;

      provider.urlController.text = 'test.com';
      provider.database = 'test_db';
      provider.emailController.text = 'test@test.com';
      provider.passwordController.text = 'password';

      final context = MockBuildContext();
      when(() => context.mounted).thenReturn(true);
      final result = await provider.login(context);

      expect(result, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('login failure', () async {
      OdooSessionManager.setAuthenticateForTesting(
        ({
          required String serverUrl,
          required String database,
          required String username,
          required String password,
        }) async => null,
      );

      when(
        () => mockConnectivity.ensureInternetOrThrow(),
      ).thenAnswer((_) async => null);
      when(
        () => mockConnectivity.ensureServerReachable(any()),
      ).thenAnswer((_) async => null);

      final provider = LoginProvider();

      // Mock form validation
      final mockFormKey = MockFormKey();
      final mockFormState = MockFormState();
      when(() => mockFormKey.currentState).thenReturn(mockFormState);
      when(() => mockFormState.validate()).thenReturn(true);
      provider.formKey = mockFormKey;

      provider.urlController.text = 'test.com';
      provider.database = 'test_db';
      provider.emailController.text = 'test@test.com';
      provider.passwordController.text = 'password';

      final context = MockBuildContext();
      when(() => context.mounted).thenReturn(true);
      final result = await provider.login(context);

      expect(result, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, contains('Login failed'));
    });

    test('togglePasswordVisibility toggles the state', () {
      final provider = LoginProvider();
      expect(provider.obscurePassword, isTrue);
      provider.togglePasswordVisibility();
      expect(provider.obscurePassword, isFalse);
      provider.togglePasswordVisibility();
      expect(provider.obscurePassword, isTrue);
    });
  });
}

class MockBuildContext extends Mock implements BuildContext {}
