import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  late MockSecureStorage mockSecureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage = MockSecureStorage();
    SecureStorageService.setInstanceForTesting(mockSecureStorage);

    when(
      () => mockSecureStorage.storePassword(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockSecureStorage.getPassword(any()),
    ).thenAnswer((_) async => 'secret');
    when(
      () => mockSecureStorage.deletePassword(any()),
    ).thenAnswer((_) async {});

    OdooSessionManager.resetForTesting();
  });

  group('AppSessionData', () {
    test('saveToPrefs and fromPrefs round-trip', () async {
      final odooSession = OdooSession(
        id: 'sess-123',
        userId: 1,
        partnerId: 1,
        companyId: 1,
        allowedCompanies: [],
        userLogin: 'user@example.com',
        userName: 'User',
        userLang: 'en_US',
        userTz: 'UTC',
        isSystem: false,
        dbName: 'testdb',
        serverVersion: '16',
      );

      final model = AppSessionData(
        odooSession: odooSession,
        password: 'secret',
        serverUrl: 'https://odoo.example.com',
        database: 'testdb',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      await model.saveToPrefs();
      final restored = await AppSessionData.fromPrefs();

      expect(restored, isNotNull);
      expect(restored!.sessionId, 'sess-123');
      expect(restored.userLogin, 'user@example.com');
      expect(restored.serverUrl, 'https://odoo.example.com');
      expect(restored.database, 'testdb');
      expect(restored.password, 'secret');
    });

    test('isExpired reflects expiresAt correctly', () {
      final odooSession = OdooSession(
        id: 's1',
        userId: 1,
        partnerId: 1,
        companyId: 1,
        allowedCompanies: [],
        userLogin: 'u',
        userName: 'U',
        userLang: 'en',
        userTz: 'UTC',
        isSystem: false,
        dbName: 'd',
        serverVersion: '16',
      );

      final fresh = AppSessionData(
        odooSession: odooSession,
        password: '',
        serverUrl: 's',
        database: 'd',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      final expired = AppSessionData(
        odooSession: odooSession,
        password: '',
        serverUrl: 's',
        database: 'd',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(fresh.isExpired, isFalse);
      expect(expired.isExpired, isTrue);
    });
  });

  group('OdooSessionManager', () {
    test('setLastServerInfo and getters persist values', () async {
      await OdooSessionManager.setLastServerInfo(
        serverUrl: 'https://odoo.example.com',
        database: 'testdb',
      );
      expect(
        await OdooSessionManager.getLastServerUrl(),
        'https://odoo.example.com',
      );
      expect(await OdooSessionManager.getLastDatabase(), 'testdb');
    });

    test('updateSession writes to prefs and can be restored', () async {
      final odooSession = OdooSession(
        id: 'sess-old',
        userId: 1,
        partnerId: 1,
        companyId: 1,
        allowedCompanies: [],
        userLogin: 'old@example.com',
        userName: 'Old',
        userLang: 'en',
        userTz: 'UTC',
        isSystem: false,
        dbName: 'db',
        serverVersion: '16',
      );

      final model = AppSessionData(
        odooSession: odooSession,
        password: 'secret',
        serverUrl: 'https://host',
        database: 'db',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await model.saveToPrefs();

      final updatedOdooSession = OdooSession(
        id: 'sess-new',
        userId: 1,
        partnerId: 1,
        companyId: 1,
        allowedCompanies: [],
        userLogin: 'new@example.com',
        userName: 'New',
        userLang: 'en',
        userTz: 'UTC',
        isSystem: false,
        dbName: 'db',
        serverVersion: '16',
      );

      final updated = model.copyWith(odooSession: updatedOdooSession);
      await OdooSessionManager.updateSession(updated);

      final restored = await OdooSessionManager.getCurrentSession();
      expect(restored, isNotNull);
      expect(restored!.sessionId, 'sess-new');
      expect(restored.userLogin, 'new@example.com');
    });

    test('isSessionValid returns true when logged in', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      expect(await OdooSessionManager.isSessionValid(), isTrue);

      await prefs.setBool('isLoggedIn', false);
      expect(await OdooSessionManager.isSessionValid(), isFalse);
    });

    test(
      'logout clears session prefs but keeps last connection info',
      () async {
        final odooSession = OdooSession(
          id: 'sess-123',
          userId: 1,
          partnerId: 1,
          companyId: 1,
          allowedCompanies: [],
          userLogin: 'user@example.com',
          userName: 'User',
          userLang: 'en',
          userTz: 'UTC',
          isSystem: false,
          dbName: 'testdb',
          serverVersion: '16',
        );

        final model = AppSessionData(
          odooSession: odooSession,
          password: 'secret',
          serverUrl: 'https://odoo.example.com',
          database: 'testdb',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await model.saveToPrefs();

        await OdooSessionManager.setLastServerInfo(
          serverUrl: 'https://odoo.example.com',
          database: 'testdb',
        );

        await OdooSessionManager.logout();

        final restored = await OdooSessionManager.getCurrentSession();
        expect(restored, isNull);

        expect(
          await OdooSessionManager.getLastServerUrl(),
          'https://odoo.example.com',
        );
        expect(await OdooSessionManager.getLastDatabase(), 'testdb');
      },
    );
  });
}
