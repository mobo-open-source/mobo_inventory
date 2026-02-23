import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/appsession.dart';
import 'secure_storage_service.dart';
import 'connectivity_service.dart';

/// Static manager class for handling raw Odoo sessions and RPC clients.
class OdooSessionManager {
  static OdooClient? _client;
  static AppSessionData? _cachedSession;
  static bool _isRefreshing = false;
  static DateTime? _lastAuthTime;

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  static const Duration _sessionCacheValidDuration = Duration(minutes: 5);

  static Function(AppSessionData)? _onSessionUpdated;
  static Function()? _onSessionCleared;

  @visibleForTesting
  static void setClientForTesting(OdooClient? client) {
    _client = client;
    _lastAuthTime = DateTime.now();
  }

  @visibleForTesting
  static void setSessionForTesting(AppSessionData? session) {
    _cachedSession = session;
    _lastAuthTime = DateTime.now();
  }

  @visibleForTesting
  static void resetForTesting() {
    _client = null;
    _cachedSession = null;
    _isRefreshing = false;
    _lastAuthTime = null;
    _onSessionUpdated = null;
    _onSessionCleared = null;
    _authenticateMock = null;
  }

  static Future<AppSessionData?> Function({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  })?
  _authenticateMock;

  @visibleForTesting
  static void setAuthenticateForTesting(
    Future<AppSessionData?> Function({
      required String serverUrl,
      required String database,
      required String username,
      required String password,
    })?
    mock,
  ) {
    _authenticateMock = mock;
  }

  static void setSessionCallbacks({
    Function(AppSessionData)? onSessionUpdated,
    Function()? onSessionCleared,
  }) {
    _onSessionUpdated = onSessionUpdated;
    _onSessionCleared = onSessionCleared;
  }

  static bool _isRetryableError(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is http.ClientException) return true;

    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('connection reset') ||
        errorStr.contains('timed out') ||
        errorStr.contains('connection refused');
  }

  /// Restores a previously saved session and forces a specific company context.
  static Future<bool> restoreSession({required int companyId}) async {
    if (companyId <= 0) return false;

    final saved = await getCurrentSession();
    if (saved == null) return false;

    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(saved.serverUrl);

      final OdooClient client = OdooClient(
        saved.serverUrl,
        sessionId: saved.odooSession,
      );

      List<int> allowed = [...saved.allowedCompanyIds];

      if (allowed.isEmpty && saved.userId != 0) {
        try {
          final userCompanies = await _fetchUserCompanies(client, saved.userId);
          final loadedAllowed =
              (userCompanies['company_ids'] as List<int>? ?? []);
          if (loadedAllowed.isNotEmpty) allowed = loadedAllowed;
        } catch (e) {}
      }

      if (!allowed.contains(companyId)) {
        allowed.add(companyId);
      }

      final refreshed = saved.copyWith(
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedCompanyId: companyId,
        allowedCompanyIds: <int>{...allowed}.toList(),
      );

      _client = client;
      _cachedSession = refreshed;
      _lastAuthTime = DateTime.now();
      await refreshed.saveToPrefs();
      ConnectivityService.instance.setCurrentServerUrl(refreshed.serverUrl);
      _onSessionUpdated?.call(refreshed);
      return true;
    } on NoInternetException catch (_) {
      return false;
    } on ServerUnreachableException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  static bool _isAuthError(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('access denied') ||
        errorStr.contains('invalid session') ||
        errorStr.contains('session expired') ||
        errorStr.contains('authentication') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('403') ||
        errorStr.contains('server error') ||
        errorStr.contains('500');
  }

  /// Retrieves the current session data from cache or preferences.
  static Future<AppSessionData?> getCurrentSession() async {
    if (_cachedSession != null) return _cachedSession;

    try {
      var saved = await AppSessionData.fromPrefs();
      if (saved == null) return null;

      if (!saved.isExpired) {
        final extendedExpiry = DateTime.now().add(const Duration(hours: 24));
        saved = saved.copyWith(expiresAt: extendedExpiry);
        await saved.saveToPrefs();
      }

      _client = OdooClient(saved.serverUrl, sessionId: saved.odooSession);
      _cachedSession = saved;
      _lastAuthTime = DateTime.now();
      ConnectivityService.instance.setCurrentServerUrl(saved.serverUrl);

      return saved;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Performs login against the Odoo server and saves the resulting session.
  static Future<bool> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
    String? sessionId,
    String? serverVersion,
    bool autoLoadCompanies = true,
  }) async {
    // Validate inputs
    if (serverUrl.isEmpty || database.isEmpty || userLogin.isEmpty) {
      throw Exception('Invalid login parameters');
    }

    if (_authenticateMock != null) {
      final session = await _authenticateMock!(
        serverUrl: serverUrl,
        database: database,
        username: userLogin,
        password: password,
      );
      if (session != null) {
        _cachedSession = session;
        _lastAuthTime = DateTime.now();
        await session.saveToPrefs();
        ConnectivityService.instance.setCurrentServerUrl(session.serverUrl);
        _onSessionUpdated?.call(session);
        return true;
      }
      return false;
    }

    // Normalize server URL
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    // Connectivity checks
    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(normalizedUrl);
    } catch (e) {
      rethrow;
    }

    OdooClient client = OdooClient(normalizedUrl);

    // Retry authentication on transient failures
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        OdooSession odooSession;
        if (sessionId != null && sessionId.isNotEmpty) {
          // Create session object manually from provided ID
          final initialSession = OdooSession(
            id: sessionId,
            dbName: database,
            userId: 0,
            // Will be updated after fetching user info
            partnerId: 0,
            companyId: 1,
            allowedCompanies: [],
            userLogin: userLogin,
            userName: '',
            userLang: 'en_US',
            userTz: 'UTC',
            isSystem: false,
            serverVersion: serverVersion ?? '',
          );

          // Re-instantiate client with this session
          client = OdooClient(normalizedUrl, sessionId: initialSession);

          // Verify session and get user info
          final sessionInfo = await client.callRPC(
            '/web/session/get_session_info',
            'call',
            {},
          );

          if (sessionInfo == null ||
              sessionInfo['uid'] == null ||
              sessionInfo['uid'] == false) {
            return false;
          }

          odooSession = OdooSession(
            id: sessionId,
            dbName: database,
            userId: sessionInfo['uid'] as int,
            partnerId: sessionInfo['partner_id'] is int
                ? sessionInfo['partner_id']
                : 0,
            userLogin: sessionInfo['username']?.toString() ?? userLogin,
            userName: sessionInfo['name']?.toString() ?? '',
            userLang:
                sessionInfo['user_context']?['lang']?.toString() ?? 'en_US',
            userTz: sessionInfo['user_context']?['tz']?.toString() ?? 'UTC',
            isSystem: sessionInfo['is_system'] == true,
            serverVersion: sessionInfo['server_version']?.toString() ?? '',
            companyId: sessionInfo['company_id'] is int
                ? sessionInfo['company_id']
                : 1,
            allowedCompanies: [],
          );

          // Re-instantiate with full session data for consistency
          client = OdooClient(normalizedUrl, sessionId: odooSession);
        } else {
          odooSession = await client.authenticate(
            database,
            userLogin,
            password,
          );
        }

        List<int> allowedCompanyIds = [];
        int? selectedCompanyId;

        if (autoLoadCompanies) {
          try {
            final userInfo = await _fetchUserCompanies(
              client,
              odooSession.userId,
            );

            // Only override if company 1 is actually allowed, otherwise keep 1 as default.
            final fetchedAllowed =
                (userInfo['company_ids'] as List?)?.cast<int>() ?? [];

            if (fetchedAllowed.isNotEmpty) {
              selectedCompanyId =
                  userInfo['company_id'] ?? fetchedAllowed.first;
              allowedCompanyIds = fetchedAllowed.isNotEmpty
                  ? fetchedAllowed
                  : [1];
            }
          } catch (e) {
            // Fallback: keep company 1
            selectedCompanyId = 3;
            allowedCompanyIds = [1];
          }
        }

        final sessionData = AppSessionData(
          odooSession: odooSession,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          selectedCompanyId: selectedCompanyId,
          allowedCompanyIds: allowedCompanyIds,
        );

        await sessionData.saveToPrefs();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastServerUrl', normalizedUrl);
        await prefs.setString('lastDatabase', database);

        _client = client;
        _cachedSession = sessionData;
        _lastAuthTime = DateTime.now();

        ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);
        _onSessionUpdated?.call(sessionData);

        return true;
      } catch (e) {
        // Handle HTML response error
        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL and ensure Odoo is running.',
          );
        }

        final errorStr = e.toString().toLowerCase();

        // Handle 2FA/TOTP errors - these must be rethrown so LoginProvider can handle them
        if (errorStr.contains('two factor') ||
            errorStr.contains('2fa') ||
            errorStr.contains('totp')) {
          rethrow;
        }

        // Special case for the "Null" cast error which often means authentication failed via oooo_rpc
        if (errorStr.contains('null') && errorStr.contains('subtype')) {
          rethrow;
        }

        // Don't retry credential errors
        if (errorStr.contains('access denied') ||
            errorStr.contains('wrong login/password') ||
            errorStr.contains('invalid database')) {
          return false;
        }

        // Retry on connection errors
        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        // Non-retryable error or exhausted retries
        if (e is NoInternetException || e is ServerUnreachableException) {
          rethrow;
        }
        return false;
      }
    }

    return false;
  }

  static Future<Map<String, dynamic>> _fetchUserCompanies(
    OdooClient client,
    int userId,
  ) async {
    try {
      final result = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final userData = result[0];

        int? companyId;
        if (userData['company_id'] is int) {
          companyId = userData['company_id'];
        } else if (userData['company_id'] is List &&
            userData['company_id'].isNotEmpty) {
          companyId = userData['company_id'][0];
        }

        List<int> companyIds = [];
        if (userData['company_ids'] is List) {
          companyIds = (userData['company_ids'] as List)
              .map((e) => e is int ? e : null)
              .whereType<int>()
              .toList();
        }

        return {'company_id': companyId, 'company_ids': companyIds};
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<AppSessionData?> authenticate({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
  }) async {
    if (serverUrl.isEmpty || database.isEmpty || username.isEmpty) {
      throw Exception('Invalid authentication parameters');
    }

    if (password.isEmpty) {
      throw Exception('Empty password - account needs re-authentication');
    }

    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    await ConnectivityService.instance.ensureInternetOrThrow();
    await ConnectivityService.instance.ensureServerReachable(normalizedUrl);

    final client = OdooClient(normalizedUrl);

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final odooSession = await client.authenticate(
          database,
          username,
          password,
        );

        final sessionData = AppSessionData(
          odooSession: odooSession,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        _cachedSession = sessionData;
        ConnectivityService.instance.setCurrentServerUrl(normalizedUrl);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastServerUrl', normalizedUrl);
        await prefs.setString('lastDatabase', database);

        return sessionData;
      } catch (e) {
        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL.',
          );
        }

        if (e.toString().toLowerCase().contains('access denied') ||
            e.toString().toLowerCase().contains('wrong login/password')) {
          throw e;
        }

        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        throw e;
      }
    }

    throw Exception('Authentication failed after $_maxRetries attempts');
  }

  static Future<void> updateSession(AppSessionData newSession) async {
    _cachedSession = newSession;
    await newSession.saveToPrefs();

    // Clear client to force re-authentication
    _client = null;
    _lastAuthTime = null;

    ConnectivityService.instance.setCurrentServerUrl(newSession.serverUrl);
    _onSessionUpdated?.call(newSession);
  }

  /// Centralized error formatting logic ported from mobo_attendance
  static String formatError(dynamic error) {
    if (error == null) return 'Authentication failed.';

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('accessdenied') ||
        errorStr.contains('access denied') ||
        errorStr.contains('wrong login/password') ||
        errorStr.contains('invalid login') ||
        (errorStr.contains('{code: 200') &&
            errorStr.contains('accessdenied'))) {
      return 'Incorrect username or password. Please check your login credentials.';
    } else if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception') ||
        errorStr.contains('<html>')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database') &&
        (errorStr.contains('not found') ||
            errorStr.contains('does not exist'))) {
      return 'Selected database is not available. Please choose a different database.';
    } else if (errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('unreachable')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. The server may be slow or unreachable.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Your account may not have permission to access this database.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL connection failed. Try using HTTP instead of HTTPS.';
    } else if (errorStr.contains('connection refused')) {
      return 'Server is not responding. Please verify the server URL and try again.';
    } else if (errorStr.contains('null') && errorStr.contains('subtype')) {
      // 2FA redirection indicator
      return '';
    } else if (errorStr.contains('two factor') ||
        errorStr.contains('2fa') ||
        errorStr.contains('totp')) {
      return ''; // Handled by redirection
    } else {
      return 'Login failed. Please check your credentials and server settings.';
    }
  }

  static Future<bool> refreshSession() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 500));
      return await isSessionValid();
    }

    _isRefreshing = true;
    try {
      final session = await getCurrentSession();

      if (session == null) {
        throw StateError('No Odoo session available. Please login.');
      }

      try {
        await ConnectivityService.instance.ensureInternetOrThrow();
        await ConnectivityService.instance.ensureServerReachable(
          session.serverUrl,
        );

        final client = OdooClient(session.serverUrl);
        final newOdooSession = await client.authenticate(
          session.database,
          session.userLogin,
          session.password,
        );

        _client = client;

        final refreshedSession = session.copyWith(
          odooSession: newOdooSession,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );

        _cachedSession = refreshedSession;
        _lastAuthTime = DateTime.now();
        await refreshedSession.saveToPrefs();
        _onSessionUpdated?.call(refreshedSession);

        ConnectivityService.instance.setCurrentServerUrl(
          refreshedSession.serverUrl,
        );

        return true;
      } on NoInternetException catch (e) {
        return false;
      } on ServerUnreachableException catch (e) {
        return false;
      } catch (e) {
        // Apply backoff: Prevent immediate retries by bumping expiry time in memory only.
        // This stops the infinite loop (getClientEnsured -> isExpired -> refresh -> fail -> repeat).
        // The backoff is NOT persisted, so app restart will retry immediately.

        if (_cachedSession != null) {
          _cachedSession = _cachedSession!.copyWith(
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
          // Do NOT save to prefs - we want persistent failure state to remain until success
        }

        return false;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  static Future<OdooClient?> getClient() async {
    try {
      return await getClientEnsured();
    } catch (e) {
      return null;
    }
  }

  static Future<OdooClient> getClientEnsured() async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No Odoo session available. Please login.');
    }

    // Check if session is expired
    if (session.isExpired) {
      final refreshed = await refreshSession();
      if (!refreshed) {
        if (_client == null) {
          // IMPORTANT: passing the expired session ID ensures Odoo returns a JSON error
          // (Code 100/Session Expired) instead of redirecting to HTML login page.
          _client = OdooClient(
            session.serverUrl,
            sessionId: session.odooSession,
          );
        }
        return _client!;
      }
    }

    // Reuse existing client if valid
    if (_client != null &&
        _lastAuthTime != null &&
        DateTime.now().difference(_lastAuthTime!) <
            _sessionCacheValidDuration) {
      return _client!;
    }

    // Create new client using existing session
    try {
      await ConnectivityService.instance.ensureInternetOrThrow();
      await ConnectivityService.instance.ensureServerReachable(
        session.serverUrl,
      );

      // Use the stored session to avoid password-based re-authentication which breaks 2FA
      final client = OdooClient(
        session.serverUrl,
        sessionId: session.odooSession,
      );

      _client = client;
      _lastAuthTime = DateTime.now();

      // Update session expiry locally
      final updatedSession = session.copyWith(
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
      _cachedSession = updatedSession;
      await updatedSession.saveToPrefs();

      return client;
    } on NoInternetException catch (e) {
      final client = OdooClient(session.serverUrl);
      _client = client;
      return client;
    }
  }

  /// Execute action with auto session refresh on auth errors
  static Future<T> callWithSession<T>(
    Future<T> Function(OdooClient client) action,
  ) async {
    final client = await getClientEnsured();

    try {
      return await action(client);
    } catch (e) {
      // Don't retry on connectivity issues
      if (e is NoInternetException || e is ServerUnreachableException) {
        rethrow;
      }

      // Retry once on auth errors
      if (_isAuthError(e)) {
        final refreshed = await refreshSession();
        if (refreshed) {
          final newClient = await getClientEnsured();
          return await action(newClient);
        } else {}
      }

      rethrow;
    }
  }

  /// Safe wrapper for callKw with automatic company context injection
  /// This is the recommended method for all RPC calls to ensure proper multi-company support
  static Future<dynamic> safeCallKw(Map<String, dynamic> payload) {
    return callKwWithCompany(payload);
  }

  /// Safe wrapper for callKw WITHOUT company context injection
  /// Use this only for system-level calls that should not be company-filtered
  /// (e.g., fetching company list, user authentication, etc.)
  static Future<dynamic> safeCallKwWithoutCompany(
    Map<String, dynamic> payload,
  ) {
    return callWithSession((client) => client.callKw(payload));
  }

  /// Safe wrapper for callRPC
  static Future<dynamic> safeCallRPC(
    String path,
    String method,
    Map<String, dynamic> args,
  ) {
    return callWithSession((client) => client.callRPC(path, method, args));
  }

  /// Fetch the list of allowed companies (id, name) for the current user.
  /// This performs:
  /// 1) Read user's company_ids
  /// 2) search_read on res.company for id, name
  static Future<List<Map<String, dynamic>>> getAllowedCompaniesList() async {
    try {
      final client = await getClientEnsured();
      final session = await getCurrentSession();
      if (session == null) return [];

      // 1) Get the allowed company IDs from the user record
      final info = await _fetchUserCompanies(client, session.userId);
      final ids = (info['company_ids'] as List?)?.cast<int>() ?? [];

      if (ids.isEmpty) {
        // Fallback to current company if allowed list is empty
        final currentId = info['company_id'] as int?;
        if (currentId != null) {
          ids.add(currentId);
        } else {
          return [];
        }
      }

      // 2) Fetch details for ONLY those specific IDs
      final companiesRes = await safeCallKwWithoutCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', ids],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      if (companiesRes is List) {
        return companiesRes.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getCompaniesForDropdown() async {
    final companies = await getAllowedCompaniesList();
    final selectedId = await getSelectedCompanyId();
    return {'companies': companies, 'selectedCompanyId': selectedId};
  }

  /// Make authenticated HTTP request with retry logic
  Future<http.Response> makeAuthenticatedRequest(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw Exception('No active Odoo session');
    }

    final headers = {
      'Cookie': 'session_id=${session.sessionId}',
      'Content-Type': 'application/json',
      'Accept':
          'application/pdf,application/octet-stream,application/json;q=0.9,*/*;q=0.8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': '${session.serverUrl}/web',
      'User-Agent': 'Mozilla/5.0 (Linux; Android) FlutterApp/1.0',
    };

    http.Response? lastResponse;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final uri = Uri.parse(url);
        final future = body != null
            ? http.post(uri, headers: headers, body: jsonEncode(body))
            : http.get(uri, headers: headers);
        final response = await future.timeout(const Duration(seconds: 20));

        // Check for HTML response (session expired)
        final contentType = response.headers['content-type'] ?? '';
        final isHtml =
            contentType.contains('text/html') ||
            (response.bodyBytes.isNotEmpty &&
                String.fromCharCodes(
                  response.bodyBytes.take(64),
                ).toLowerCase().contains('<!doctype html'));

        if (isHtml && attempt < _maxRetries) {
          await refreshSession();
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        // Retry on server errors
        if ([502, 503, 504].contains(response.statusCode) &&
            attempt < _maxRetries) {
          lastResponse = response;
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        return response;
      } catch (e) {
        if (attempt >= _maxRetries || !_isRetryableError(e)) rethrow;
        final delay = _baseDelay * attempt;
        await Future.delayed(delay);
      }
    }

    if (lastResponse != null) return lastResponse;
    throw Exception('Request to $url failed after $_maxRetries attempts');
  }

  static Future<int?> getSelectedCompanyId() async {
    // First check if we have it in the cached session
    final session = await getCurrentSession();
    if (session?.companyId != null) {
      return session!.companyId;
    }

    // Fallback to reading from preferences directly
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('selected_company_id');
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> getSelectedAllowedCompanyIds() async {
    // First check if we have it in the cached session
    final session = await getCurrentSession();
    if (session != null && session.allowedCompanyIds.isNotEmpty) {
      return session.allowedCompanyIds;
    }

    // Fallback to reading from preferences directly
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('selected_allowed_company_ids') ?? [];
      return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e > 0).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> updateCompanySelection({
    required int companyId,
    required List<int> allowedCompanyIds,
  }) async {
    final session = await getCurrentSession();
    if (session == null) {
      return;
    }

    // Ensure selected company is in allowed companies
    List<int> finalAllowedIds = [...allowedCompanyIds];
    if (!finalAllowedIds.contains(companyId)) {
      finalAllowedIds.add(companyId);
    }

    // Update session with new company info
    final updatedSession = session.copyWith(
      selectedCompanyId: companyId,
      allowedCompanyIds: finalAllowedIds,
    );

    _cachedSession = updatedSession;
    await updatedSession.saveToPrefs();

    _onSessionUpdated?.call(updatedSession);
  }

  static Future<void> clearCompanySelection() async {
    final session = await getCurrentSession();
    if (session == null) return;

    final updatedSession = session.copyWith(
      selectedCompanyId: null,
      allowedCompanyIds: [],
    );

    _cachedSession = updatedSession;
    await updatedSession.saveToPrefs();

    _onSessionUpdated?.call(updatedSession);
  }

  /// Call Odoo method with company context
  /// Automatically injects company_id and allowed_company_ids into the request context
  static Future<dynamic> callKwWithCompany(
    Map<String, dynamic> payload, {
    int? companyId,
    List<int>? allowedCompanyIds,
  }) async {
    final map = Map<String, dynamic>.from(payload);

    Map<String, dynamic> kwargs = {};
    final rawKwargs = map['kwargs'];
    if (rawKwargs is Map) {
      kwargs = rawKwargs.map((key, value) => MapEntry(key.toString(), value));
    }

    Map<String, dynamic> ctx = {};
    final rawCtx = kwargs['context'];
    if (rawCtx is Map) {
      ctx = rawCtx.map((key, value) => MapEntry(key.toString(), value));
    }

    // Get company info from parameters, session, or preferences (in that order)
    int? selectedCompany = companyId;
    List<int>? allowed = allowedCompanyIds;

    if (selectedCompany == null || allowed == null) {
      final session = await getCurrentSession();
      selectedCompany ??= session?.companyId ?? await getSelectedCompanyId();
      allowed ??= session?.allowedCompanyIds.isNotEmpty == true
          ? session!.allowedCompanyIds
          : await getSelectedAllowedCompanyIds();
    }

    if (selectedCompany != null) {
      ctx['company_id'] = selectedCompany;

      // Ensure selected company is in allowed companies
      List<int> finalAllowed = [...(allowed ?? [])];
      if (!finalAllowed.contains(selectedCompany)) {
        finalAllowed.add(selectedCompany);
      }

      ctx['allowed_company_ids'] = <int>{...finalAllowed}.toList();
    }

    kwargs['context'] = ctx;
    map['kwargs'] = kwargs;

    return callWithSession((client) => client.callKw(map));
  }

  static Future<void> logout() async {
    final session = _cachedSession ?? await getCurrentSession();
    if (session?.userId != null) {
      await SecureStorageService.instance.deletePassword(
        'session_password_${session!.userId}',
      );
    }

    _client = null;
    _cachedSession = null;
    _isRefreshing = false;
    _lastAuthTime = null;

    ConnectivityService.instance.setCurrentServerUrl(null);

    final prefs = await SharedPreferences.getInstance();

    const keysToRemove = [
      'sessionId',
      'userLogin',
      'database',
      'serverUrl',
      'userId',
      'expiresAt',
      'isLoggedIn',
      'selected_company_id',
      'selected_allowed_company_ids',
    ];

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    _onSessionCleared?.call();
  }

  static void clearClientCache() {
    _client = null;
    _lastAuthTime = null;
  }

  static Future<String?> getLastServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastServerUrl');
  }

  static Future<String?> getLastDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastDatabase');
  }

  static Future<void> setLastServerInfo({
    required String serverUrl,
    required String database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastServerUrl', serverUrl);
    await prefs.setString('lastDatabase', database);
  }
}
