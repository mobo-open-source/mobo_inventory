import 'package:flutter/foundation.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import '../models/replenishment_orderpoint.dart';

class ReplenishmentService {

  List<dynamic> _buildDomain({
    String? searchQuery,
    bool notSnoozed = true,
    String trigger = 'manual',
  }) {
    final domain = <dynamic>[];
    if (notSnoozed) {

      domain.add('|');
      domain.add(['snoozed_until', '=', false]);
      domain.add(['snoozed_until', '<=', DateTime.now().toIso8601String().split('T')[0]]);
    }
    if (trigger.isNotEmpty) {
      domain.add(['trigger', '=', trigger]);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {

      domain.add('|');
      domain.add(['name', 'ilike', searchQuery.trim()]);
      domain.add(['product_id', 'ilike', searchQuery.trim()]);
    }
    return domain;
  }

  Future<List<ReplenishmentOrderpoint>> fetchOrderpoints({
    String? searchQuery,
    bool notSnoozed = true,
    String trigger = 'manual',
    int limit = 80,
    int offset = 0,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();

    final kwargs = {
      'fields': [],
      'limit': limit,
      'offset': offset,
      'order': 'id ASC',
      'context': {
        'lang': 'en_US',
        'tz': 'Asia/Calcutta',
        'uid': session?.userId,
      },
      'domain': _buildDomain(
        searchQuery: searchQuery,
        notSnoozed: notSnoozed,
        trigger: trigger,
      ),
    };

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'search_read',
        'args': [],
        'kwargs': kwargs,
      });
      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((e) => ReplenishmentOrderpoint.fromJson(e)).toList();
    } catch (e) {
            rethrow;
    }
  }

  Future<int> getCount({
    String? searchQuery,
    bool notSnoozed = true,
    String trigger = 'manual',
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    final domain = _buildDomain(
      searchQuery: searchQuery,
      notSnoozed: notSnoozed,
      trigger: trigger,
    );
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {
          'context': {
            'lang': 'en_US',
            'tz': 'Asia/Calcutta',
            'uid': session?.userId,
          },
        },
      });
      return (res as int);
    } catch (e) {
            rethrow;
    }
  }

  Future<void> actionReplenish({
    required List<int> ids,
    String trigger = 'manual',
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'action_replenish',
        'args': [ids],
        'kwargs': {
          'context': {
            'lang': 'en_US',
            'tz': 'Asia/Calcutta',
            'uid': session?.userId,
            'default_trigger': trigger,
          },
        },
      });
    } catch (e) {
            rethrow;
    }
  }

  Future<void> actionReplenishAuto({
    required List<int> ids,
    String trigger = 'manual',
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'action_replenish_auto',
        'args': [ids],
        'kwargs': {
          'context': {
            'params': {
              'debug': 1,
              'action': 'replenishment',
              'actionStack': [
                {'action': 'replenishment'}
              ],
            },
            'lang': 'en_US',
            'tz': 'Asia/Calcutta',
            'uid': session?.userId,
            'default_trigger': trigger,
          },
        },
      });
    } catch (e) {
            rethrow;
    }
  }

  Future<void> snoozeOrderpoints({
    required List<int> ids,
    required String predefinedDate,
    DateTime? customDate,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    try {
      final Map<String, dynamic> context = {
        'lang': 'en_US',
        'tz': 'Asia/Calcutta',
        'uid': session?.userId,
        'default_orderpoint_ids': ids,
        'default_predefined_date': predefinedDate,
        'active_model': 'stock.warehouse.orderpoint',
        'active_ids': ids,
        'active_id': ids.isNotEmpty ? ids.first : null,
        'params': {
          'debug': 1,
          'action': 'replenishment',
          'actionStack': [
            {'action': 'replenishment'}
          ],
        },
      };

      if (predefinedDate == 'custom' && customDate != null) {
        final String dateStr = customDate.toIso8601String().split('T').first;
        context['default_snoozed_until'] = dateStr;
      }

      final created = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.orderpoint.snooze',
        'method': 'create',
        'args': [
          {

          }
        ],
        'kwargs': {
          'context': context,
        },
      });
      final int wizardId = (created is int)
          ? created
          : (created is num)
              ? created.toInt()
              : int.parse(created.toString());

      final Map<String, dynamic> saveVals = {

        'orderpoint_ids': ids.map((e) => [4, e]).toList(),
        'predefined_date': predefinedDate,
      };
      if (predefinedDate == 'custom' && customDate != null) {
        saveVals['snoozed_until'] = context['default_snoozed_until'];
      }
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.orderpoint.snooze',
        'method': 'write',
        'args': [
          [wizardId],
          saveVals,
        ],
        'kwargs': {
          'context': context,
        },
      });

      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.orderpoint.snooze',
        'method': 'action_snooze',
        'args': [
          [wizardId],
        ],
        'kwargs': {
          'context': context,
        },
      });
    } catch (e) {
            rethrow;
    }
  }

  Future<void> updateOrderpointValues({
    required int id,
    double? minQty,
    double? maxQty,
    double? manualToOrderQty,
  }) async {
    final Map<String, dynamic> vals = {};
    if (minQty != null) vals['product_min_qty'] = minQty;
    if (maxQty != null) vals['product_max_qty'] = maxQty;
    if (manualToOrderQty != null) vals['qty_to_order_manual'] = manualToOrderQty;

    if (vals.isEmpty) return;

    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'write',
        'args': [
          [id],
          vals,
        ],
        'kwargs': {},
      });
    } catch (e) {
            rethrow;
    }
  }

  Future<void> updateMinQty({required int id, required double minQty}) async {
    await updateOrderpointValues(id: id, minQty: minQty);
  }

  Future<void> updateMaxQty({required int id, required double maxQty}) async {
    await updateOrderpointValues(id: id, maxQty: maxQty);
  }

  Future<void> updateManualToOrderQty({required int id, required double qty}) async {
    await updateOrderpointValues(id: id, manualToOrderQty: qty);
  }
}
