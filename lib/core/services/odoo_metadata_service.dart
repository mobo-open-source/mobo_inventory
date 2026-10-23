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

      // The `ir.model` lookup above failed for a reason OTHER than
      // connectivity (e.g. an access error on `ir.model` itself, or a
      // session hiccup) — that is NOT proof the model is missing, so fall
      // through to a second, more direct check before drawing any
      // conclusion.
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

        // Only cache "missing" when the server explicitly says the model
        // doesn't exist. Any other failure here (access rights, an expired
        // session that hadn't refreshed yet, a transient server error) is
        // ambiguous and must NOT be memoized as "not installed" — that cache
        // never expires, so a single bad moment (e.g. mid session-refresh)
        // would permanently hide this feature for the rest of the app
        // session even after the real condition clears up.
        final errStr = e2.toString().toLowerCase();
        final confirmedMissing = errStr.contains('invalid model name') ||
            errStr.contains("keyerror: '${model.toLowerCase()}'") ||
            errStr.contains('object has no attribute') ||
            (errStr.contains('model') &&
                (errStr.contains('does not exist') ||
                    errStr.contains('not found')));

        if (confirmedMissing) {
          _modelCache[model] = false;
          return false;
        }

        // Ambiguous failure — don't cache anything, assume present so the
        // real data fetch proceeds and surfaces its own accurate error
        // instead of a misleading "please install this app" message.
        return true;
      }
    }
  }

  static void reset() {
    _modelCache.clear();
  }
}
