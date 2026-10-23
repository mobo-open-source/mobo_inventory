import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appsession.dart';
import 'odoo_session_manager.dart';
import 'odoo_metadata_service.dart';
import 'secure_storage_service.dart';
import 'connectivity_service.dart';
import '../utils/base64_utils.dart';

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
    unawaited(_syncStoredAccount(newSession));
  }

  /// Keeps the saved entry for [session]'s account in step with the session
  /// that just became current: its live `sessionId`, the `isCurrent` flag and
  /// `lastLogin`.
  ///
  /// Runs on every committed session change — login, switch, a silent
  /// re-auth — and on nothing provisional, since the session manager holds
  /// those callbacks back. Without it the saved `sessionId` goes stale after
  /// the first switch, so every later switch fell back to a password login
  /// (a new server session each time) and a 2FA account asked for a code on
  /// every switch. Accounts not saved yet are left to [storeAccount], which
  /// also fetches their name and avatar.
  Future<void> _syncStoredAccount(AppSessionData session) async {
    final index = _storedAccountIndex(session);
    if (index == -1) return;

    final existing = _storedAccounts[index];
    final alreadyInStep =
        existing['sessionId'] == session.sessionId &&
        existing['isCurrent'] == true;
    if (alreadyInStep) return;

    for (final account in _storedAccounts) {
      account['isCurrent'] = false;
    }
    _storedAccounts[index] = {
      ...existing,
      'sessionId': session.sessionId,
      'isCurrent': true,
      'lastLogin': DateTime.now().toIso8601String(),
    };
    await _saveStoredAccountsWithRetry();
    notifyListeners();
  }

  int _storedAccountIndex(AppSessionData session) => _storedAccounts.indexWhere(
    (account) =>
        account['userId']?.toString() == session.userId.toString() &&
        (account['serverUrl'] ?? account['url']) == session.serverUrl &&
        account['database'] == session.database,
  );

  /// Refreshes the saved name and avatar of [session]'s account.
  ///
  /// The account switcher shows what [storeAccount] saved at sign-in, so a
  /// rename — in the profile screen or in Odoo itself — stayed invisible there
  /// until that account signed in again. Takes the session the data was read
  /// for rather than the current one, so a switch while a profile read is in
  /// flight cannot put one account's name on another. Writes only when
  /// something changed: the avatar is a full base64 image.
  Future<void> updateStoredAccountProfile(
    AppSessionData session, {
    String? name,
    String? imageBase64,
  }) async {
    final index = _storedAccountIndex(session);
    if (index == -1) return;

    final existing = _storedAccounts[index];
    final updated = Map<String, dynamic>.from(existing);
    if (name != null && name.isNotEmpty && name != 'false') {
      updated['name'] = name;
      updated['userName'] = name;
    }
    if (imageBase64 != null) {
      updated['imageBase64'] = imageBase64.isNotEmpty ? imageBase64 : null;
    }
    if (mapEquals(updated, existing)) return;

    _storedAccounts[index] = updated;
    await _saveStoredAccountsWithRetry();
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

      // A one-off failure while probing model existence earlier in this
      // session (e.g. mid session-expiry) permanently caches "module not
      // installed" for that model — clear it so the next login re-probes
      // from scratch instead of carrying that stale, possibly-wrong verdict
      // into the new session.
      OdooMetadataService.reset();

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
      // The name the server already reported for this session, when it has
      // one; the login stands in until the read below answers.
      String userDisplayName =
          (session.userName.isNotEmpty && session.userName != 'false')
          ? session.userName
          : session.userLogin;

      try {
        // A client scoped to THIS session rather than the globally active
        // one: during Add Account the global client can still belong to the
        // previous account, which saved the new account under the old one's
        // name and avatar.
        final client = OdooClient(
          session.serverUrl,
          sessionId: session.odooSession,
        );

        try {
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
            final img = odooBinaryToBase64(user['image_1920']);
            if (img.isNotEmpty) {
              imageBase64 = img;
            }
          }
        } finally {
          client.close();
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
