import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService secureStorageService;

  setUp(() {
    // Initialize with empty values for each test
    FlutterSecureStorage.setMockInitialValues({});
    secureStorageService = SecureStorageService.instance;
  });

  group('SecureStorageService Tests', () {
    test('storePassword should save value', () async {
      const key = 'test_key';
      const value = 'test_password';

      await secureStorageService.storePassword(key, value);
      final storedValue = await secureStorageService.getPassword(key);

      expect(storedValue, equals(value));
    });

    test('storePassword should not save empty value', () async {
      const key = 'test_key';
      const value = '';

      await secureStorageService.storePassword(key, value);
      final storedValue = await secureStorageService.getPassword(key);

      expect(storedValue, isNull);
    });

    test('getPassword should return null for non-existent key', () async {
      final value = await secureStorageService.getPassword('non_existent_key');
      expect(value, isNull);
    });

    test('deletePassword should remove value', () async {
      const key = 'test_key';
      const value = 'test_password';

      await secureStorageService.storePassword(key, value);
      await secureStorageService.deletePassword(key);
      final storedValue = await secureStorageService.getPassword(key);

      expect(storedValue, isNull);
    });

    test('deletePasswordsByPattern should remove matching keys', () async {
      await secureStorageService.storePassword('user_1_pass', 'pass1');
      await secureStorageService.storePassword('user_2_pass', 'pass2');
      await secureStorageService.storePassword('other_key', 'other');

      await secureStorageService.deletePasswordsByPattern('user_');

      expect(await secureStorageService.getPassword('user_1_pass'), isNull);
      expect(await secureStorageService.getPassword('user_2_pass'), isNull);
      expect(
        await secureStorageService.getPassword('other_key'),
        equals('other'),
      );
    });

    test('clearAll should remove all values', () async {
      await secureStorageService.storePassword('key1', 'val1');
      await secureStorageService.storePassword('key2', 'val2');

      await secureStorageService.clearAll();

      expect(await secureStorageService.getPassword('key1'), isNull);
      expect(await secureStorageService.getPassword('key2'), isNull);
    });

    test('hasPassword should return correct boolean', () async {
      const key = 'test_key';

      expect(await secureStorageService.hasPassword(key), isFalse);

      await secureStorageService.storePassword(key, 'value');
      expect(await secureStorageService.hasPassword(key), isTrue);
    });
  });
}
