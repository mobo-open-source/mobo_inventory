import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'odoo_session_manager.dart';

class ModuleValidationService {
  ModuleValidationService._();
  static final ModuleValidationService instance = ModuleValidationService._();

  static const String _cacheKeyModuleStatus = 'module_validation_status';
  static const String _cacheKeyLastCheck = 'module_validation_last_check';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  Future<Map<String, bool>> validateRequiredModules({
    bool forceRefresh = false,
  }) async {
    final sessionValid = await OdooSessionManager.isSessionValid();
    if (!sessionValid) {
      return {};
    }

    if (!forceRefresh) {
      final cached = await _loadCachedStatus();
      if (cached != null) {
        return cached;
      }
    }

    final results = <String, bool>{};

    try {
      final inventoryInstalled = await _checkModule('stock');
      results['stock'] = inventoryInstalled;

      final productInstalled = await _checkModule('product');
      results['product'] = productInstalled;

      await _cacheStatus(results);

      return results;
    } catch (e) {
      return {};
    }
  }

  Future<bool> _checkModule(String moduleName) async {
    try {
      final sessionValid = await OdooSessionManager.isSessionValid();
      if (!sessionValid) return false;

      final result = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            ['name', '=', moduleName],
            ['state', '=', 'installed'],
          ],
        ],
        'kwargs': {},
      });

      return (result as int) > 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isInventoryInstalled({bool forceRefresh = false}) async {
    final status = await validateRequiredModules(forceRefresh: forceRefresh);
    return status['stock'] ?? false;
  }

  Future<bool> isProductInstalled({bool forceRefresh = false}) async {
    final status = await validateRequiredModules(forceRefresh: forceRefresh);
    return status['product'] ?? false;
  }

  String getMissingModulesMessage(Map<String, bool> moduleStatus) {
    final missing = <String>[];

    if (moduleStatus['stock'] == false) {
      missing.add('Inventory (stock)');
    }
    if (moduleStatus['product'] == false) {
      missing.add('Product');
    }

    if (missing.isEmpty) {
      return '';
    }

    final modules = missing.join(', ');
    return 'The following required modules are not installed on your Odoo server: $modules.\n\n'
        'This app requires the Inventory module to function properly. '
        'Please contact your administrator to install the required modules.';
  }

  Future<Map<String, bool>?> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString(_cacheKeyLastCheck);

      if (lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);
        final now = DateTime.now();

        if (now.difference(lastCheck) < _cacheValidDuration) {
          final statusStr = prefs.getString(_cacheKeyModuleStatus);
          if (statusStr != null) {
            final parts = statusStr.split(',');
            final status = <String, bool>{};
            for (final part in parts) {
              final kv = part.split(':');
              if (kv.length == 2) {
                status[kv[0]] = kv[1] == 'true';
              }
            }
            return status;
          }
        }
      }
    } catch (e) {}
    return null;
  }

  Future<void> _cacheStatus(Map<String, bool> status) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final statusStr = status.entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');

      await prefs.setString(_cacheKeyModuleStatus, statusStr);
      await prefs.setString(
        _cacheKeyLastCheck,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {}
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyModuleStatus);
      await prefs.remove(_cacheKeyLastCheck);
    } catch (e) {}
  }
}
