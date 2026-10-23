import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_storage_service.dart';

/// Data model representing a logged-in Odoo session.
/// Contains authentication details, server URL, and company context.
class AppSessionData {
  final OdooSession odooSession;
  final String password;
  final String serverUrl;
  final String database;
  final DateTime? expiresAt;
  final int? selectedCompanyId;
  final List<int> allowedCompanyIds;

  const AppSessionData({
    required this.odooSession,
    required this.password,
    required this.serverUrl,
    required this.database,
    this.expiresAt,
    this.selectedCompanyId,
    this.allowedCompanyIds = const [],
  });

  /// Returns true if the session has exceeded its expiration time.
  bool get isExpired =>
      expiresAt != null ? DateTime.now().isAfter(expiresAt!) : false;

  String get userLogin => odooSession.userLogin;
  String get userName => odooSession.userName;
  int get userId => odooSession.userId;
  String get sessionId => odooSession.id;
  int get companyId => selectedCompanyId ?? odooSession.companyId;

  AppSessionData copyWith({
    OdooSession? odooSession,
    String? password,
    String? serverUrl,
    String? database,
    DateTime? expiresAt,
    int? selectedCompanyId,
    List<int>? allowedCompanyIds,
  }) {
    return AppSessionData(
      odooSession: odooSession ?? this.odooSession,
      password: password ?? this.password,
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      expiresAt: expiresAt ?? this.expiresAt,
      selectedCompanyId: selectedCompanyId ?? this.selectedCompanyId,
      allowedCompanyIds: allowedCompanyIds ?? this.allowedCompanyIds,
    );
  }

  /// Persists the session data to [SharedPreferences] and passwords to secure storage.
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('sessionId', odooSession.id);
    await prefs.setString('userLogin', odooSession.userLogin);
    await prefs.setString('database', database);
    await prefs.setString('serverUrl', serverUrl);
    await prefs.setString('serverVersion', odooSession.serverVersion);
    await prefs.setInt('userId', odooSession.userId);

    if (expiresAt != null) {
      await prefs.setString('expiresAt', expiresAt!.toIso8601String());
    } else {
      await prefs.remove('expiresAt');
    }

    if (selectedCompanyId != null) {
      await prefs.setInt('selected_company_id', selectedCompanyId!);
    } else {
      await prefs.remove('selected_company_id');
    }

    await prefs.setStringList(
      'selected_allowed_company_ids',
      allowedCompanyIds.map((e) => e.toString()).toList(),
    );
    await prefs.setString('userName', odooSession.userName);
    await prefs.setBool('isLoggedIn', true);

    // Scoped to the database, and the same keys the account switcher reads
    // (SessionService.retrievePasswordWithMultiplePatterns). The old keys
    // were not: `session_password_<uid>` is shared by every account with the
    // same user id — admin is uid 2 on every Odoo database — so saving one
    // overwrote the other's password.
    //
    // Never written when empty: a session restored from a saved session id
    // carries no password of its own, and writing '' here wiped the real one
    // — the next launch then found no password and signed the user out, and
    // the account switcher had nothing left to switch back with.
    if (password.isEmpty) return;
    await SecureStorageService.instance.storePassword(
      'password_${odooSession.userLogin}_$database',
      password,
    );
    await SecureStorageService.instance.storePassword(
      'password_${odooSession.userId}_$database',
      password,
    );
  }

  /// The current session's password, from the database-scoped keys, falling
  /// back to the legacy unscoped ones an older install wrote. A legacy hit is
  /// re-saved under the scoped keys, so an existing sign-in survives the
  /// upgrade instead of being treated as missing its password.
  static Future<String?> _loadPassword({
    required String userLogin,
    required int userId,
    required String database,
  }) async {
    final storage = SecureStorageService.instance;
    for (final key in [
      'password_${userLogin}_$database',
      'password_${userId}_$database',
    ]) {
      final value = await storage.getPassword(key);
      if (value != null && value.isNotEmpty) return value;
    }

    for (final key in [
      'session_password_username_$userLogin',
      'session_password_$userId',
    ]) {
      final value = await storage.getPassword(key);
      if (value != null && value.isNotEmpty) {
        await storage.storePassword('password_${userLogin}_$database', value);
        await storage.storePassword('password_${userId}_$database', value);
        return value;
      }
    }
    return null;
  }

  /// Loads the session data from [SharedPreferences] and secure storage.
  /// Returns null if no valid session data is found.
  static Future<AppSessionData?> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return null;

    final sessionId = prefs.getString('sessionId');
    final userLogin = prefs.getString('userLogin');
    final database = prefs.getString('database');
    String? serverUrl = prefs.getString('serverUrl');
    final userId = prefs.getInt('userId');
    final serverVersion = prefs.getString('serverVersion') ?? '16';

    if ([sessionId, userLogin, database, serverUrl, userId].contains(null)) {
      return null;
    }

    serverUrl = serverUrl!.trim();
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = 'https://$serverUrl';
    }

    final password = await _loadPassword(
      userLogin: userLogin!,
      userId: userId!,
      database: database!,
    );
    if (password == null || password.isEmpty) return null;

    DateTime? expiresAt;
    final expiresAtStr = prefs.getString('expiresAt');
    if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
      try {
        expiresAt = DateTime.parse(expiresAtStr);
      } catch (_) {}
    }

    int? companyId;
    if (prefs.containsKey('selected_company_id')) {
      companyId = prefs.getInt('selected_company_id');
    }

    final allowedRaw =
        prefs.getStringList('selected_allowed_company_ids') ?? const [];
    final allowed = allowedRaw
        .map((e) => int.tryParse(e) ?? -1)
        .where((e) => e > 0)
        .toList();

    final odooSession = OdooSession(
      id: sessionId!,
      userId: userId,
      partnerId: 0,
      companyId: companyId ?? 0,
      allowedCompanies: [],
      userLogin: userLogin,
      userName: prefs.getString('userName') ?? '',
      userLang: 'en_US',
      userTz: 'UTC',
      isSystem: false,
      dbName: database,
      serverVersion: serverVersion,
    );

    return AppSessionData(
      odooSession: odooSession,
      password: password,
      serverUrl: serverUrl,
      database: database,
      expiresAt: expiresAt,
      selectedCompanyId: companyId,
      allowedCompanyIds: allowed,
    );
  }
}
