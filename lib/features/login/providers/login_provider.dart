import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/database_service.dart';
import '../pages/totp_page.dart';

/// Provider for managing the login flow, including server validation and database fetching.
class LoginProvider with ChangeNotifier {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool urlCheck = false;
  bool disableFields = false;
  String? database;
  String? errorMessage;
  bool isLoading = false;
  bool isLoadingDatabases = false;
  List<String> dropdownItems = [];
  OdooClient? client;
  bool obscurePassword = true;
  List<String> _previousUrls = [];
  List<String> get previousUrls => _previousUrls;
  final Map<String, String> _serverDatabaseMap = {};
  bool _disposed = false;
  String _selectedProtocol = 'https://';
  String get selectedProtocol => _selectedProtocol;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final TextEditingController urlController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final OdooClient Function(String)? clientFactory;
  final DatabaseService _databaseService;

  LoginProvider({this.clientFactory, DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService() {
    _loadSavedCredentials();
  }

  String? _resolveSavedDatabaseForUrl(String fullUrl) {
    if (_serverDatabaseMap.containsKey(fullUrl)) {
      return _serverDatabaseMap[fullUrl];
    }

    String alt;
    if (fullUrl.startsWith('https://')) {
      alt = 'http://${fullUrl.substring(8)}';
    } else if (fullUrl.startsWith('http://')) {
      alt = 'https://${fullUrl.substring(7)}';
    } else {
      alt = 'https://$fullUrl';
      if (_serverDatabaseMap.containsKey(alt)) return _serverDatabaseMap[alt];
      alt = 'http://$fullUrl';
      if (_serverDatabaseMap.containsKey(alt)) return _serverDatabaseMap[alt];
      return null;
    }
    if (_serverDatabaseMap.containsKey(alt)) {
      return _serverDatabaseMap[alt];
    }

    String stripSlash(String u) =>
        u.endsWith('/') ? u.substring(0, u.length - 1) : u;
    final noSlash = stripSlash(fullUrl);
    if (_serverDatabaseMap.containsKey(noSlash)) {
      return _serverDatabaseMap[noSlash];
    }
    final altNoSlash = stripSlash(alt);
    if (_serverDatabaseMap.containsKey(altNoSlash)) {
      return _serverDatabaseMap[altNoSlash];
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    urlController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void setProtocol(String protocol) {
    _selectedProtocol = protocol;
    notifyListeners();
  }

  void setLoading(bool value) {
    isLoading = value;
    if (value) {
      disableFields = true;
      errorMessage = null;
    } else {
      disableFields = false;
    }
    _safeNotifyListeners();
  }

  Future<void> seedUrlToHistory(String fullUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fullUrl.isEmpty) return;
      List<String> urls = prefs.getStringList('previous_server_urls') ?? [];

      String u = fullUrl.endsWith('/')
          ? fullUrl.substring(0, fullUrl.length - 1)
          : fullUrl;

      urls.removeWhere((e) => e == u);
      urls.insert(0, u);
      if (urls.length > 10) {
        urls = urls.take(10).toList();
      }
      await prefs.setStringList('previous_server_urls', urls);
      _previousUrls = urls;
      _safeNotifyListeners();
    } catch (_) {}
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final historyUrls = prefs.getStringList('previous_server_urls') ?? [];

      final Set<String> orderedUnique = <String>{};

      String _normalize(String url) {
        String u = url.trim();
        if (u.isEmpty) return u;

        if (!u.startsWith('http://') && !u.startsWith('https://')) {
          u = '$_selectedProtocol$u';
        }
        if (u.endsWith('/')) u = u.substring(0, u.length - 1);
        return u;
      }

      void addUrl(String? url) {
        if (url == null) return;
        final normalized = _normalize(url);
        if (normalized.isEmpty) return;
        orderedUnique.add(normalized);
      }

      try {
        final lastFromPrefs = prefs.getString('lastServerUrl');

        if (lastFromPrefs != null && lastFromPrefs.isNotEmpty) {
          addUrl(lastFromPrefs);
        } else {
          final lastViaMgr = await OdooSessionManager.getLastServerUrl();
          addUrl(lastViaMgr);
        }
      } catch (_) {}

      try {
        final current = await OdooSessionManager.getCurrentSession();
        addUrl(current?.serverUrl);
      } catch (_) {}

      try {
        final accounts = SessionService.instance.storedAccounts;
        for (final acc in accounts) {
          addUrl(acc['url']?.toString());
          addUrl(acc['serverUrl']?.toString());
        }
      } catch (_) {}

      for (final u in historyUrls) {
        addUrl(u);
      }

      _previousUrls = orderedUnique.toList();

      try {
        final rawMap = prefs.getString('server_db_map');
        if (rawMap != null && rawMap.isNotEmpty) {
          final Map<String, dynamic> decoded = Map<String, dynamic>.from(
            jsonDecode(rawMap),
          );
          decoded.forEach((k, v) {
            if (v is String && v.isNotEmpty) {
              _serverDatabaseMap[k] = v;
            }
          });
        }
      } catch (_) {}

      try {
        final mappingKeys = prefs.getKeys().where(
          (key) => key.startsWith('server_db_'),
        );
        for (final key in mappingKeys) {
          final serverUrl = key.substring(10);
          final dbName = prefs.getString(key);
          if (dbName != null) {
            _serverDatabaseMap[serverUrl] = dbName;
          }
        }
      } catch (_) {}

      final lastServer = prefs.getString('lastServerUrl');
      final lastDb = prefs.getString('lastDatabase');
      if ((lastServer != null && lastServer.isNotEmpty) &&
          (lastDb != null && lastDb.isNotEmpty)) {
        _serverDatabaseMap[lastServer] = lastDb;
      }

      _isInitialized = true;
      _safeNotifyListeners();
    } catch (e) {
      _isInitialized = true;
      _safeNotifyListeners();
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullUrl = getFullUrl();

      List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
      if (fullUrl.isNotEmpty && !urls.contains(fullUrl)) {
        urls.insert(0, fullUrl);
        if (urls.length > 10) {
          urls = urls.take(10).toList();
        }
        await prefs.setStringList('previous_server_urls', urls);
        _previousUrls = urls;
      }

      if (fullUrl.isNotEmpty && database != null && database!.isNotEmpty) {
        await prefs.setString('server_db_$fullUrl', database!);
        _serverDatabaseMap[fullUrl] = database!;

        try {
          final existing = prefs.getString('server_db_map');
          final Map<String, dynamic> map =
              existing != null && existing.isNotEmpty
              ? Map<String, dynamic>.from(jsonDecode(existing))
              : <String, dynamic>{};
          map[fullUrl] = database!;
          await prefs.setString('server_db_map', jsonEncode(map));
        } catch (_) {}
      }
    } catch (e) {}
  }

  String _normalizeUrl(String url) {
    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = '$_selectedProtocol$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    return normalizedUrl;
  }

  String getFullUrl() {
    final url = urlController.text.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '$_selectedProtocol$url';
  }

  String extractProtocol(String fullUrl) {
    if (fullUrl.startsWith('https://')) return 'https://';
    if (fullUrl.startsWith('http://')) return 'http://';
    return _selectedProtocol;
  }

  String extractDomain(String fullUrl) {
    if (fullUrl.startsWith('https://')) return fullUrl.substring(8);
    if (fullUrl.startsWith('http://')) return fullUrl.substring(7);
    return fullUrl;
  }

  void setUrlFromFullUrl(String fullUrl) {
    final protocol = extractProtocol(fullUrl);
    final domain = extractDomain(fullUrl);
    _selectedProtocol = protocol;
    urlController.text = domain;
  }

  void clearForm() {
    urlController.clear();
    emailController.clear();
    passwordController.clear();
    database = null;
    dropdownItems.clear();
    urlCheck = false;
    errorMessage = null;
    isLoading = false;
    isLoadingDatabases = false;
    disableFields = false;
    notifyListeners();
  }

  /// Fetches the list of available databases from the configured server URL.
  Future<void> fetchDatabaseList() async {
    if (urlController.text.trim().isEmpty) {
      _resetDatabaseState();
      errorMessage = 'Please enter a server URL first.';
      _safeNotifyListeners();
      return;
    }

    if (!isValidUrl(urlController.text.trim())) {
      _resetDatabaseState();
      errorMessage = 'Please enter a valid server URL.';
      _safeNotifyListeners();
      return;
    }

    final String? previousSelection = database;

    isLoadingDatabases = true;
    urlCheck = false;
    errorMessage = null;

    dropdownItems.clear();
    _safeNotifyListeners();

    try {
      final baseUrl = _normalizeUrl(urlController.text);

      final response = await Future.any([
        _databaseService.fetchDatabaseList(baseUrl),
        Future.delayed(const Duration(seconds: 15)).then(
          (_) => throw TimeoutException(
            'Request timed out',
            const Duration(seconds: 15),
          ),
        ),
      ]);

      final dbList = response;
      if (dbList.isEmpty) {
        errorMessage = 'No databases found on this server.';
        urlCheck = false;
      } else {
        final uniqueDbList = dbList.toSet().toList();
        uniqueDbList.sort((a, b) => a.toString().compareTo(b.toString()));
        dropdownItems = uniqueDbList.map((e) => e.toString()).toList();
        urlCheck = true;

        try {
          final prefs = await SharedPreferences.getInstance();
          final fullUrl = getFullUrl();
          if (fullUrl.isNotEmpty) {
            List<String> urls =
                prefs.getStringList('previous_server_urls') ?? [];
            if (!urls.contains(fullUrl)) {
              urls.insert(0, fullUrl);
              if (urls.length > 10) {
                urls = urls.take(10).toList();
              }
              await prefs.setStringList('previous_server_urls', urls);
              _previousUrls = urls;
            }
          }
        } catch (_) {}

        final fullUrl = getFullUrl();
        final savedDatabase = _resolveSavedDatabaseForUrl(fullUrl);

        if (savedDatabase != null && dropdownItems.contains(savedDatabase)) {
          database = savedDatabase;
        } else if (previousSelection != null &&
            dropdownItems.contains(previousSelection)) {
          database = previousSelection;
        } else {
          try {
            final lastUrl = await OdooSessionManager.getLastServerUrl();
            final lastDb = await OdooSessionManager.getLastDatabase();

            String normalize(String u) {
              String x = u.trim();
              if (x.endsWith('/')) x = x.substring(0, x.length - 1);
              return x;
            }

            bool urlsMatch(String? a, String? b) {
              if (a == null || b == null) return false;
              final A = normalize(a);
              final B = normalize(b);

              String stripProto(String s) =>
                  s.replaceFirst(RegExp('^https?://'), '');
              return stripProto(A) == stripProto(B);
            }

            if (lastUrl != null &&
                lastDb != null &&
                dropdownItems.contains(lastDb) &&
                urlsMatch(lastUrl, fullUrl)) {
              database = lastDb;
            }
          } catch (_) {}

          if (database == null && uniqueDbList.isNotEmpty) {
            database = uniqueDbList.first.toString();
          }
        }
      }
    } on SocketException catch (e) {
      if (e.toString().contains('Network is unreachable')) {
        errorMessage =
            'No internet connection. Please check your network settings and try again.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage =
            'Server is not responding. Please verify the server URL and ensure the server is running.';
      } else {
        errorMessage =
            'Network error occurred. Please check your internet connection and server URL.';
      }
      _resetDatabaseState();
    } on TimeoutException catch (_) {
      errorMessage =
          'Connection timed out. The server may be slow or unreachable. Please try again.';
      _resetDatabaseState();
    } on OdooException catch (e) {
      errorMessage = _formatOdooError(e);
      _resetDatabaseState();
    } on FormatException catch (e) {
      if (e.toString().toLowerCase().contains('html')) {
        errorMessage =
            'Invalid server response. This may not be an Odoo server or the URL path is incorrect.';
      } else {
        errorMessage =
            'Server sent invalid data format. Please verify this is an Odoo server.';
      }
      _resetDatabaseState();
    } catch (e) {
      errorMessage =
          'Unable to connect to server. Please verify the server URL is correct.';
      _resetDatabaseState();
    } finally {
      isLoadingDatabases = false;
      _safeNotifyListeners();
    }
  }

  void _resetDatabaseState() {
    database = null;
    urlCheck = false;
    dropdownItems.clear();
  }

  String _formatOdooError(OdooException e) {
    final message = e.message.toLowerCase();
    if (message.contains('404') || message.contains('not found')) {
      return 'Server not found. Please verify your server URL is correct and the server is running.';
    } else if (message.contains('403') || message.contains('forbidden')) {
      return 'Access denied. The server may not allow database listing or requires authentication.';
    } else if (message.contains('500') ||
        message.contains('internal server error')) {
      return 'Server error occurred. Please contact your system administrator or try again later.';
    } else if (message.contains('timeout') || message.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    } else if (message.contains('ssl') || message.contains('certificate')) {
      return 'SSL certificate error. Try using HTTP instead of HTTPS, or contact your administrator.';
    } else if (message.contains('connection refused') ||
        message.contains('refused')) {
      return 'Connection refused. Please verify the server URL and port number are correct.';
    } else {
      return 'Unable to connect to server. Please check your server URL and internet connection.';
    }
  }

  void setDatabase(String? value) {
    database = value;
    notifyListeners();
  }

  /// Performs login using the provided credentials and selected database.
  Future<bool> login(BuildContext context) async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return false;
    }
    if (database == null || database!.isEmpty) {
      errorMessage = 'Please select a database first.';
      _safeNotifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    disableFields = true;
    _safeNotifyListeners();

    try {
      final serverUrl = _normalizeUrl(urlController.text);
      final userLogin = emailController.text.trim();
      final password = passwordController.text.trim();

      if (serverUrl.isEmpty || userLogin.isEmpty || password.isEmpty) {
        throw Exception('Please fill in all required fields.');
      }

      final loginSuccess = await OdooSessionManager.loginAndSaveSession(
        serverUrl: serverUrl,
        database: database!,
        userLogin: userLogin,
        password: password,
      );

      if (loginSuccess) {
        await _saveCredentials();
        await _setAuthenticationTimestamp();

        try {
          final sessionService = SessionService.instance;
          final currentSession = await OdooSessionManager.getCurrentSession();

          if (currentSession != null) {
            await sessionService.storeAccount(currentSession, password);
          }
        } catch (e) {}

        return true;
      } else {
        errorMessage = 'Login failed. Please check your credentials.';
        return false;
      }
    } on SocketException catch (e) {
      if (e.toString().contains('Network is unreachable')) {
        errorMessage =
            'No internet connection. Please check your network settings.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage =
            'Server is not responding. Please verify the server URL is correct.';
      } else {
        errorMessage =
            'Network error occurred. Please check your internet connection and server URL.';
      }
      return false;
    } on TimeoutException catch (e) {
      errorMessage =
          'Connection timed out. The server may be slow or unreachable. Please try again.';
      return false;
    } on OdooException catch (e) {
      final message = e.message.toLowerCase();

      if (message.contains('two factor') ||
          message.contains('two-factor') ||
          message.contains('2fa') ||
          message.contains('totp') ||
          message.contains('token_expired')) {
        if (context.mounted) {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TotpPage(
                protocol: selectedProtocol,
                serverUrl: _normalizeUrl(urlController.text),
                database: database!,
                username: emailController.text.trim(),
                password: passwordController.text.trim(),
              ),
            ),
          );
        }
        return false;
      }

      if (message.contains('invalid login') ||
          message.contains('access denied')) {
        errorMessage =
            'Incorrect email or password. Please check your login credentials.';
      } else if (message.contains('database')) {
        errorMessage =
            'Database access failed. Please verify the selected database is correct.';
      } else {
        errorMessage = _formatOdooError(e);
      }
      return false;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('two factor') ||
          errorStr.contains('two-factor') ||
          errorStr.contains('2fa') ||
          errorStr.contains('totp') ||
          errorStr.contains('token_expired') ||
          (errorStr.contains('null') && errorStr.contains('subtype'))) {
        if (context.mounted) {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TotpPage(
                protocol: selectedProtocol,
                serverUrl: _normalizeUrl(urlController.text),
                database: database!,
                username: emailController.text.trim(),
                password: passwordController.text.trim(),
              ),
            ),
          );
        }
        return false;
      }

      errorMessage = _formatError(e);
      return false;
    } finally {
      isLoading = false;
      disableFields = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _setAuthenticationTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('lastSuccessfulAuth', currentTime);
    } catch (_) {}
  }

  bool isValidUrl(String url) {
    try {
      String urlToValidate = url.trim();
      if (urlToValidate.isEmpty) return false;

      final urlRegExp = RegExp(
        r'^(https?:\/\/)?'
        r'(([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|'
        r'((\d{1,3}\.){3}\d{1,3})'
        r'(\:\d+)?(\/[-a-z\d%_.~+]*)*'
        r'(\?[;&a-z\d%_.~+=-]*)?'
        r'(\#[-a-z\d_]*)?$',
        caseSensitive: false,
      );

      if (!urlRegExp.hasMatch(urlToValidate)) {
        if (urlToValidate.contains(' ') || urlToValidate.contains('!!'))
          return false;
      }

      if (!urlToValidate.startsWith('http://') &&
          !urlToValidate.startsWith('https://')) {
        urlToValidate = '$_selectedProtocol$urlToValidate';
      }
      final uri = Uri.parse(urlToValidate);
      return uri.hasScheme && uri.host.isNotEmpty && !uri.host.contains(' ');
    } catch (e) {
      return false;
    }
  }

  bool get isFormReady {
    return urlController.text.trim().isNotEmpty &&
        emailController.text.trim().isNotEmpty &&
        passwordController.text.trim().isNotEmpty &&
        database != null &&
        database!.isNotEmpty &&
        !isLoading &&
        !isLoadingDatabases;
  }

  String _formatError(dynamic e) {
    if (e is OdooException) {
      return _formatOdooError(e);
    }

    final message = e.toString().toLowerCase();
    if (message.contains('socketexception') || message.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    return 'Login failed. Please check your credentials and server settings.';
  }
}
