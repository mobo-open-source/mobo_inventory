import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

/// A service that provides secure storage for sensitive data like passwords.
/// Uses [FlutterSecureStorage] with platform-specific secure options.
class SecureStorageService {
  static SecureStorageService _instance = SecureStorageService._internal();
  static SecureStorageService get instance => _instance;
  SecureStorageService._internal();

  @visibleForTesting
  static void setInstanceForTesting(SecureStorageService service) {
    _instance = service;
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Stores a password securely under the given [key].
  Future<void> storePassword(String key, String password) async {
    if (password.isEmpty) return;
    await _storage.write(key: key, value: password);
  }

  /// Retrieves a password for the given [key]. Returns null if not found.
  Future<String?> getPassword(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deletePassword(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deletePasswordsByPattern(String pattern) async {
    final allKeys = await _storage.readAll();
    final keys = allKeys.keys.toList();
    for (final key in keys) {
      if (key.contains(pattern)) {
        await _storage.delete(key: key);
      }
    }
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Checks if a password exists for the given [key].
  Future<bool> hasPassword(String key) async {
    final value = await _storage.read(key: key);
    return value != null && value.isNotEmpty;
  }
}
