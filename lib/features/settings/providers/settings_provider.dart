import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool _isLoadingLanguages = false;
  bool _isLoadingCurrencies = false;
  bool _isLoadingTimezones = false;

  bool _isDarkMode = false;
  bool _enableNotifications = true;
  bool _reduceMotion = false;
  double _cacheSize = 0.0;

  List<Map<String, dynamic>> _availableLanguages = [];
  List<Map<String, dynamic>> _availableCurrencies = [];
  List<Map<String, dynamic>> _availableTimezones = [];

  DateTime? _languagesUpdatedAt;
  DateTime? _currenciesUpdatedAt;
  DateTime? _timezonesUpdatedAt;

  String _selectedLanguage = 'en_US';
  String _selectedCurrency = 'USD';
  String _selectedTimezone = 'UTC';

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isDarkMode => _isDarkMode;
  bool get enableNotifications => _enableNotifications;
  bool get reduceMotion => _reduceMotion;
  double get cacheSize => _cacheSize;

  bool get isLoadingLanguages => _isLoadingLanguages;
  bool get isLoadingCurrencies => _isLoadingCurrencies;
  bool get isLoadingTimezones => _isLoadingTimezones;

  List<Map<String, dynamic>> get availableLanguages => _availableLanguages;
  List<Map<String, dynamic>> get availableCurrencies => _availableCurrencies;
  List<Map<String, dynamic>> get availableTimezones => _availableTimezones;

  DateTime? get languagesUpdatedAt => _languagesUpdatedAt;
  DateTime? get currenciesUpdatedAt => _currenciesUpdatedAt;
  DateTime? get timezonesUpdatedAt => _timezonesUpdatedAt;

  String get selectedLanguage => _selectedLanguage;
  String get selectedCurrency => _selectedCurrency;
  String get selectedTimezone => _selectedTimezone;

  Future<void> initialize() async {
    await loadLocalSettings();

    fetchAllLanguageRegionData();
  }

  Future<void> loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enableNotifications = prefs.getBool('enable_notifications') ?? true;
      _reduceMotion = prefs.getBool('reduce_motion') ?? false;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;

      _selectedLanguage = prefs.getString('selected_language') ?? 'en_US';
      _selectedCurrency = prefs.getString('selected_currency') ?? 'USD';
      _selectedTimezone = prefs.getString('selected_timezone') ?? 'UTC';

      final cachedLangs = prefs.getString('available_languages');
      final cachedCurrencies = prefs.getString('available_currencies');
      final cachedTimezones = prefs.getString('available_timezones');

      if (cachedLangs != null && cachedLangs.isNotEmpty) {
        try {
          _availableLanguages = List<Map<String, dynamic>>.from(
            jsonDecode(cachedLangs),
          );
        } catch (_) {}
      }
      if (cachedCurrencies != null && cachedCurrencies.isNotEmpty) {
        try {
          _availableCurrencies = List<Map<String, dynamic>>.from(
            jsonDecode(cachedCurrencies),
          );
        } catch (_) {}
      }
      if (cachedTimezones != null && cachedTimezones.isNotEmpty) {
        try {
          _availableTimezones = List<Map<String, dynamic>>.from(
            jsonDecode(cachedTimezones),
          );
        } catch (_) {}
      }

      final langsTs = prefs.getInt('langs_updated_at');
      final currsTs = prefs.getInt('currs_updated_at');
      final tzTs = prefs.getInt('tz_updated_at');

      if (langsTs != null && langsTs > 0) {
        _languagesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(langsTs);
      }
      if (currsTs != null && currsTs > 0) {
        _currenciesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(currsTs);
      }
      if (tzTs != null && tzTs > 0) {
        _timezonesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(tzTs);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load settings: $e';
      notifyListeners();
    }
  }

  Future<void> saveLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_notifications', _enableNotifications);
      await prefs.setBool('reduce_motion', _reduceMotion);
      await prefs.setBool('dark_mode', _isDarkMode);

      await prefs.setString('selected_language', _selectedLanguage);
      await prefs.setString('selected_currency', _selectedCurrency);
      await prefs.setString('selected_timezone', _selectedTimezone);

      await prefs.setString(
        'available_languages',
        jsonEncode(_availableLanguages),
      );
      await prefs.setString(
        'available_currencies',
        jsonEncode(_availableCurrencies),
      );
      await prefs.setString(
        'available_timezones',
        jsonEncode(_availableTimezones),
      );

      if (_languagesUpdatedAt != null) {
        await prefs.setInt(
          'langs_updated_at',
          _languagesUpdatedAt!.millisecondsSinceEpoch,
        );
      }
      if (_currenciesUpdatedAt != null) {
        await prefs.setInt(
          'currs_updated_at',
          _currenciesUpdatedAt!.millisecondsSinceEpoch,
        );
      }
      if (_timezonesUpdatedAt != null) {
        await prefs.setInt(
          'tz_updated_at',
          _timezonesUpdatedAt!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      _error = 'Failed to save settings: $e';
          }
  }

  Future<void> updateDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
      _isDarkMode = value;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update dark mode: $e';
      notifyListeners();
    }
  }

  Future<void> updateNotifications(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_notifications', value);
      _enableNotifications = value;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update notifications: $e';
      notifyListeners();
    }
  }

  Future<void> updateReduceMotion(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reduce_motion', value);
      _reduceMotion = value;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update reduce motion: $e';
      notifyListeners();
    }
  }

  Future<void> fetchAllLanguageRegionData() async {
    await Future.wait([
      fetchAvailableLanguages(),
      fetchAvailableCurrencies(),
      fetchAvailableTimezones(),
    ]);
  }

  Future<void> fetchAvailableLanguages({bool markManual = false}) async {
    _isLoadingLanguages = true;
    notifyListeners();

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.lang',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
          ['code', 'name', 'iso_code', 'direction'],
        ],
        'kwargs': {'order': 'name'},
      });

      if (result != null) {
        _availableLanguages = List<Map<String, dynamic>>.from(result);
        _languagesUpdatedAt = DateTime.now();
        await saveLocalSettings();
      }
    } catch (e) {
      
      if (_availableLanguages.isEmpty) {
        _availableLanguages = [
          {'code': 'en_US', 'name': 'English (US)'},
          {'code': 'es_ES', 'name': 'Spanish'},
          {'code': 'fr_FR', 'name': 'French'},
          {'code': 'de_DE', 'name': 'German'},
          {'code': 'ar_001', 'name': 'Arabic'},
        ];
      }
    } finally {
      _isLoadingLanguages = false;
      notifyListeners();
    }
  }

  Future<void> fetchAvailableCurrencies({bool markManual = false}) async {
    _isLoadingCurrencies = true;
    notifyListeners();

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.currency',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
          ['name', 'full_name', 'symbol', 'position'],
        ],
        'kwargs': {'order': 'name'},
      });

      if (result != null) {
        _availableCurrencies = List<Map<String, dynamic>>.from(result);
        _currenciesUpdatedAt = DateTime.now();
        await saveLocalSettings();
      }
    } catch (e) {
      
      if (_availableCurrencies.isEmpty) {
        _availableCurrencies = [
          {'name': 'USD', 'full_name': 'US Dollar', 'symbol': '\$'},
          {'name': 'EUR', 'full_name': 'Euro', 'symbol': '€'},
          {'name': 'GBP', 'full_name': 'British Pound', 'symbol': '£'},
          {'name': 'INR', 'full_name': 'Indian Rupee', 'symbol': '₹'},
        ];
      }
    } finally {
      _isLoadingCurrencies = false;
      notifyListeners();
    }
  }

  Future<void> fetchAvailableTimezones({bool markManual = false}) async {
    _isLoadingTimezones = true;
    notifyListeners();

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [
          ['tz'],
        ],
        'kwargs': {
          'attributes': ['selection', 'string'],
        },
      });

      final tzField = (result != null)
          ? result['tz'] as Map<String, dynamic>?
          : null;
      final selection = tzField != null
          ? tzField['selection'] as List<dynamic>?
          : null;

      if (selection != null && selection.isNotEmpty) {
        _availableTimezones = selection.map<Map<String, dynamic>>((item) {
          if (item is List && item.length >= 2) {
            return {'code': item[0].toString(), 'name': item[1].toString()};
          }
          return {'code': item.toString(), 'name': item.toString()};
        }).toList();
        _timezonesUpdatedAt = DateTime.now();
        await saveLocalSettings();
      }
    } catch (e) {
      
      if (_availableTimezones.isEmpty) {
        _availableTimezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'America/New_York', 'name': 'Eastern Time (US & Canada)'},
          {'code': 'Europe/London', 'name': 'London'},
          {'code': 'Asia/Kolkata', 'name': 'Mumbai, Kolkata, New Delhi'},
        ];
      }
    } finally {
      _isLoadingTimezones = false;
      notifyListeners();
    }
  }

  Future<void> updateLanguage(String value) async {
    await updateUserPreferences(language: value);
  }

  Future<void> updateCurrency(String value) async {
    _selectedCurrency = value;
    await saveLocalSettings();
    notifyListeners();
  }

  Future<void> updateTimezone(String value) async {
    await updateUserPreferences(timezone: value);
  }

  Future<void> updateUserPreferences({
    String? language,
    String? timezone,
  }) async {
    _error = null;
    try {
      final session = await OdooSessionManager.getCurrentSession();

      if (session == null) {
        throw Exception('No active session');
      }

      final updateData = <String, dynamic>{};
      if (language != null) updateData['lang'] = language;
      if (timezone != null) updateData['tz'] = timezone;

      if (updateData.isNotEmpty) {
        await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [session.userId],
            updateData,
          ],
          'kwargs': {},
        });

        if (language != null) _selectedLanguage = language;
        if (timezone != null) _selectedTimezone = timezone;

        await saveLocalSettings();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update user preferences: $e';
            rethrow;
    }
  }

  String getLanguageDisplayName(String code) {
    final language = _availableLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'name': code},
    );
    return language['name'] ?? code;
  }

  String getCurrencyDisplayName(String code) {
    final currency = _availableCurrencies.firstWhere(
      (curr) => curr['name'] == code,
      orElse: () => {'full_name': code},
    );
    return currency['full_name'] ?? code;
  }

  String getTimezoneDisplayName(String code) {
    final timezone = _availableTimezones.firstWhere(
      (tz) => tz['code'] == code,
      orElse: () => {'name': code},
    );
    return timezone['name'] ?? code;
  }

  Future<void> calculateCacheSize() async {

    _cacheSize = 0.0;
    notifyListeners();
  }

  Future<void> clearCache({Function? onClearProviderCaches}) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (onClearProviderCaches != null) {
        await onClearProviderCaches();
      }

      final prefs = await SharedPreferences.getInstance();
      final keysToKeep = [
        'dark_mode',
        'enable_notifications',
        'reduce_motion',
        'selected_language',
        'selected_currency',
        'selected_timezone',
      ];
      final allKeys = prefs.getKeys();

      for (final key in allKeys) {
        if (!keysToKeep.contains(key)) {
          await prefs.remove(key);
        }
      }

      _cacheSize = 0.0;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear cache: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}
