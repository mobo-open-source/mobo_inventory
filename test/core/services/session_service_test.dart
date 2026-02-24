import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:mobo_inv_app/core/services/session_service.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionService sessionService;

  setUp(() async {
    // Reset services
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    OdooSessionManager.resetForTesting();

    // Create new instance
    sessionService = SessionService();
    // We access the internal singleton via the factory, but better if we could reset it.
    // SessionService is a singleton. access via .instance or factory.
    // Ideally we should have a reset method on SessionService.
    // I noticed I added resetForTesting to SessionService in my thought process, let's check if it exists in the file I read.
    // Yes, line 21 calls resetForTesting.
    sessionService.resetForTesting();
  });

  group('SessionService Tests', () {
    test('initial state should be uninitialized', () {
      expect(sessionService.isInitialized, isFalse);
      expect(sessionService.currentSession, isNull);
    });

    test('initialize should load empty state when no prefs', () async {
      await sessionService.initialize();
      expect(sessionService.isInitialized, isTrue);
      expect(sessionService.currentSession, isNull);
    });

    test('initialize should load session from prefs', () async {
      // Setup mock data
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'sessionId': 'sess_123',
        'userLogin': 'admin',
        'database': 'test_db',
        'serverUrl': 'https://test.com',
        'userId': 1,
      });

      // Setup secure storage for password
      await SecureStorageService.instance.storePassword(
        'session_password_username_admin',
        'password123',
      );

      // Pre-populate OdooSessionManager using updateSession (hacky but works if manager is used)
      // Or just rely on OdooSessionManager reading prefs.

      await sessionService.initialize();

      expect(sessionService.isInitialized, isTrue);
      // It might be null because OdooSessionManager checks internet
      // But mock initial values should be enough for AppSessionData.fromPrefs to work
      // OdooSessionManager.getCurrentSession tries fromPrefs first.

      expect(sessionService.currentSession, isNotNull);
      expect(sessionService.currentSession?.serverUrl, 'https://test.com');
    });

    test('logout should clear session', () async {
      // Simulate logged in
      SharedPreferences.setMockInitialValues({
        'isLoggedIn': true,
        'sessionId': 'sess_123',
        'userLogin': 'admin',
        'database': 'test_db',
        'serverUrl': 'https://test.com',
        'userId': 1,
      });
      await SecureStorageService.instance.storePassword(
        'session_password_username_admin',
        'password123',
      );

      await sessionService.initialize();
      expect(sessionService.hasValidSession, isTrue);

      await sessionService.logout();
      expect(sessionService.hasValidSession, isFalse);
    });
  });
}
