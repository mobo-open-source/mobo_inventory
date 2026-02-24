import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appsession.dart';
import 'odoo_session_manager.dart';
import 'secure_storage_service.dart';
import 'connectivity_service.dart';

/// High-level service for handling application sessions and stored accounts.
/// Extends [ChangeNotifier] to provide reactive session state to the UI.
class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();
  factory SessionService() => instance;
  SessionService._internal();

  AppSessionData? _currentSession;
  bool _isInitialized = false;
  bool _isServerUnreachable = false;
  List<Map<String, dynamic>> _storedAccounts = [];

  @visibleForTesting
  void resetForTesting() {
    _currentSession = null;
    _isInitialized = false;
    _storedAccounts = [];
  }

  AppSessionData? get currentSession => _currentSession;
  bool get isInitialized => _isInitialized;
  bool get hasValidSession => _currentSession != null;
  bool get isServerUnreachable => _isServerUnreachable;
  List<Map<String, dynamic>> get storedAccounts => _storedAccounts;

  /// Initializes the session service by loading stored credentials and setting up listeners.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    OdooSessionManager.setSessionCallbacks(
      onSessionUpdated: (sessionModel) {
        updateSession(sessionModel);
      },
      onSessionCleared: () {
        clearSession();
      },
    );

    _currentSession = await OdooSessionManager.getCurrentSession();

    await _loadStoredAccounts();

    await _migratePasswordsToSecureStorage();

    if (_currentSession != null) {
      await _autoStoreCurrentSession();
    }

    _isInitialized = true;

    ConnectivityService.instance.onServerChanged.listen((isReachable) {
      setServerUnreachable(!isReachable);
    });

    notifyListeners();
  }

  void setServerUnreachable(bool unreachable) {
    if (_isServerUnreachable != unreachable) {
      _isServerUnreachable = unreachable;
      notifyListeners();
    }
  }

  Future<void> checkConnectivity() async {
    if (_currentSession == null) return;
    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(
        _currentSession!.serverUrl,
      );
      setServerUnreachable(false);
    } catch (e) {
      setServerUnreachable(true);
    }
  }

  void updateSession(AppSessionData newSession) {
    _currentSession = newSession;
    notifyListeners();
  }

  void clearSession() {
    _currentSession = null;
    notifyListeners();
  }

  /// Logs out the user and clears all session-related data.
  Future<void> logout() async {
    final currentServerUrl = _currentSession?.serverUrl;
    final currentDatabase = _currentSession?.database;

    try {
      try {
        await OdooSessionManager.logout();
      } catch (e) {}

      try {
        await _clearStoredAccountsData();
      } catch (e) {}

      try {
        await _clearPasswordCaches();
      } catch (e) {}

      if (currentServerUrl != null && currentServerUrl.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastServerUrl', currentServerUrl);

          if (currentDatabase != null && currentDatabase.isNotEmpty) {
            await prefs.setString('lastDatabase', currentDatabase);
            await prefs.setString(
              'server_db_$currentServerUrl',
              currentDatabase,
            );
          }

          List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
          if (!urls.contains(currentServerUrl)) {
            urls.insert(0, currentServerUrl);
            if (urls.length > 10) {
              urls = urls.take(10).toList();
            }
            await prefs.setStringList('previous_server_urls', urls);
          }
        } catch (e) {}
      }
    } catch (e) {
    } finally {
      clearSession();
    }
  }

  Future<void> _loadStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> storedAccountsJson =
          prefs.getStringList('stored_accounts') ?? [];

      _storedAccounts = storedAccountsJson
          .map((json) {
            try {
              final decoded = Map<String, dynamic>.from(jsonDecode(json));
              return decoded;
            } catch (e) {
              return null;
            }
          })
          .where((account) => account != null)
          .cast<Map<String, dynamic>>()
          .toList();

      await _cleanupDuplicateAccounts();

      notifyListeners();
    } catch (e) {
      _storedAccounts = [];
    }
  }

  Future<void> _autoStoreCurrentSession() async {
    if (_currentSession == null) return;

    final currentExists = _storedAccounts.any(
      (account) =>
          account['userId'] == _currentSession!.userId.toString() &&
          account['serverUrl'] == _currentSession!.serverUrl &&
          account['database'] == _currentSession!.database,
    );

    if (!currentExists) {
      await storeAccount(_currentSession!, '');
    }
  }

  Future<void> _cleanupDuplicateAccounts() async {
    final uniqueAccounts = <String, Map<String, dynamic>>{};

    for (final account in _storedAccounts) {
      final userId = account['userId']?.toString() ?? '';
      final serverUrl = account['serverUrl']?.toString() ?? '';
      final database = account['database']?.toString() ?? '';

      if (userId.isEmpty || serverUrl.isEmpty || database.isEmpty) {
        continue;
      }

      final key = '${userId}_${serverUrl}_$database';

      if (!uniqueAccounts.containsKey(key)) {
        uniqueAccounts[key] = account;
      } else {
        final existing = uniqueAccounts[key]!;
        final currentHasPassword =
            account['password']?.toString().isNotEmpty == true;
        final existingHasPassword =
            existing['password']?.toString().isNotEmpty == true;

        if (currentHasPassword && !existingHasPassword) {
          uniqueAccounts[key] = account;
        }
      }
    }

    final originalCount = _storedAccounts.length;
    _storedAccounts = uniqueAccounts.values.toList();

    if (_storedAccounts.length != originalCount) {
      await _saveStoredAccountsWithRetry();
    }
  }

  /// Stores a new account's credentials and updates its display name and avatar.
  Future<void> storeAccount(
    AppSessionData session,
    String password, {
    bool markAsCurrent = true,
  }) async {
    try {
      String? imageBase64;
      String userDisplayName = session.userLogin;

      try {
        final client = await OdooSessionManager.getClient();

        if (client != null && session.userId != null) {
          final userDetails = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              ['name', 'image_1920'],
            ],
            'kwargs': {},
          });

          if (userDetails is List && userDetails.isNotEmpty) {
            final user = userDetails.first as Map;
            final n = user['name'];
            if (n != null && n != false) {
              userDisplayName = n.toString();
            }
            final img = user['image_1920'];
            if (img != null && img != false) {
              imageBase64 = img.toString();
            }
          }
        }
      } catch (e) {}

      final accountData = {
        'id': session.userId.toString(),
        'name': userDisplayName,
        'email': session.userLogin,
        'url': session.serverUrl.trim(),
        'database': session.database,
        'username': session.userLogin,
        'isCurrent': markAsCurrent,
        'lastLogin': DateTime.now().toIso8601String(),
        'imageBase64': imageBase64?.isNotEmpty == true ? imageBase64 : null,

        'userId': session.userId.toString(),
        'userName': userDisplayName,
        'serverUrl': session.serverUrl,

        'sessionId': session.sessionId,
      };

      if (markAsCurrent) {
        for (var account in _storedAccounts) {
          account['isCurrent'] = false;
        }
      }

      final existingIndex = _storedAccounts.indexWhere(
        (account) =>
            account['id'] == accountData['id'] &&
            account['url'] == accountData['url'] &&
            account['database'] == accountData['database'],
      );

      if (existingIndex != -1) {
        _storedAccounts[existingIndex] = accountData;
      } else {
        _storedAccounts.insert(0, accountData);
      }

      await _saveStoredAccountsWithRetry();

      if (password.isNotEmpty) {
        await _storePasswordWithMultiplePatterns(session, password);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _storePasswordWithMultiplePatterns(
    AppSessionData session,
    String password,
  ) async {
    if (password.isEmpty) return;

    try {
      final secureStorage = SecureStorageService.instance;

      await secureStorage.storePassword(
        'password_${session.userId}_${session.database}',
        password,
      );
      await secureStorage.storePassword(
        'password_${session.userLogin}_${session.database}',
        password,
      );
    } catch (e) {}
  }

  Future<String?> retrievePasswordWithMultiplePatterns(
    Map<String, dynamic> accountData,
  ) async {
    try {
      final secureStorage = SecureStorageService.instance;
      final userId = accountData['id'] ?? accountData['userId'];
      final username = accountData['username'] ?? accountData['email'];
      final database = accountData['database'];

      List<String> passwordKeys = [
        'password_${userId}_$database',
        'password_${username}_$database',
      ];

      for (String key in passwordKeys) {
        final password = await secureStorage.getPassword(key);
        if (password != null && password.isNotEmpty) {
          return password;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveStoredAccountsWithRetry() async {
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();

        final updatedAccountsJson = _storedAccounts
            .map((account) => jsonEncode(account))
            .toList();

        await prefs.setStringList('stored_accounts', updatedAccountsJson);

        return;
      } catch (e) {
        if (attempt == maxRetries) {
        } else {
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }
    }
  }

  Future<void> removeStoredAccount(int accountIndex) async {
    if (accountIndex < 0 || accountIndex >= _storedAccounts.length) {
      return;
    }

    final accountData = _storedAccounts[accountIndex];

    _storedAccounts.removeAt(accountIndex);
    await _saveStoredAccountsWithRetry();
    notifyListeners();
  }

  Future<bool> updateSessionDirectly(AppSessionData newSession) async {
    try {
      _currentSession = newSession;

      await OdooSessionManager.updateSession(newSession);

      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> switchToAccount(AppSessionData newSession) async {
    return await updateSessionDirectly(newSession);
  }

  Future<void> updateAccountCredentials(
    String username,
    String password,
  ) async {
    if (_currentSession != null) {
      await _storePasswordWithMultiplePatterns(_currentSession!, password);
    }
  }

  Future<void> _clearStoredAccountsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stored_accounts');
      _storedAccounts = [];
    } catch (e) {}
  }

  Future<void> _clearPasswordCaches() async {
    try {
      await SecureStorageService.instance.clearAll();
    } catch (e) {}
  }

  Future<void> _migratePasswordsToSecureStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool('passwords_migrated') == true) {
        return;
      }

      final secureStorage = SecureStorageService.instance;
      int migratedCount = 0;

      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('password_')) {
          final password = prefs.getString(key);
          if (password != null && password.isNotEmpty) {
            await secureStorage.storePassword(key, password);
            await prefs.remove(key);
            migratedCount++;
          }
        }
      }

      await prefs.setBool('passwords_migrated', true);
    } catch (e) {}
  }
}
