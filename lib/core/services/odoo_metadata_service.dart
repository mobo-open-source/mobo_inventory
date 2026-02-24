import 'package:flutter/foundation.dart';

import 'odoo_session_manager.dart';
import 'connectivity_service.dart';

class OdooMetadataService {
  static final Map<String, bool> _modelCache = {};

  static Future<bool> hasModel(String model) async {
    if (_modelCache.containsKey(model)) return _modelCache[model] ?? false;
    try {
      final res = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'ir.model',
        'method': 'search_count',
        'args': [
          [
            ['model', '=', model],
          ],
        ],
        'kwargs': const {},
      });
      final ok = (res is int ? res : 0) > 0;
      _modelCache[model] = ok;
      return ok;
    } catch (e) {
      if (e is NoInternetException || e is ServerUnreachableException) {
        rethrow;
      }

      try {
        final res = await OdooSessionManager.callKwWithCompany({
          'model': model,
          'method': 'fields_get',
          'args': [],
          'kwargs': {
            'attributes': ['string'],
          },
        });
        final ok = res is Map<String, dynamic> && res.isNotEmpty;
        _modelCache[model] = ok;
        return ok;
      } catch (e2) {
        if (e2 is NoInternetException || e2 is ServerUnreachableException) {
          rethrow;
        }

        _modelCache[model] = false;
        return false;
      }
    }
  }

  static void reset() {
    _modelCache.clear();
  }
}
