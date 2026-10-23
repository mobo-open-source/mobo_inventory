import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import '../models/replenishment_orderpoint.dart';
import '../../../core/odoo/odoo_read_group.dart';

/// One group of a server-side group-by: its display [label], the raw
/// group-by [value] (a record id, or `false` for "none") and how many
/// orderpoints fall in it.
class ReplenishmentGroup {
  final String key;
  final String label;
  final dynamic value;
  final int count;

  const ReplenishmentGroup({
    required this.key,
    required this.label,
    required this.value,
    required this.count,
  });
}

class ReplenishmentService {
  /// The same filters as Odoo's Replenishment search view: "Not Snoozed",
  /// "To Reorder" and the trigger. An empty [trigger] means both manual and
  /// automatic rules.
  List<dynamic> buildDomain({
    String? searchQuery,
    bool notSnoozed = true,
    bool toReorder = false,
    String trigger = 'manual',
  }) {
    final domain = <dynamic>[];
    if (notSnoozed) {
      domain.add('|');
      domain.add(['snoozed_until', '=', false]);
      domain.add(['snoozed_until', '<=', _odooDate(DateTime.now())]);
    }
    if (toReorder) {
      domain.add(['qty_to_order', '>', 0.0]);
    }
    if (trigger.isNotEmpty) {
      domain.add(['trigger', '=', trigger]);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      domain.add('|');
      domain.add('|');
      domain.add(['name', 'ilike', q]);
      domain.add(['product_id', 'ilike', q]);
      domain.add(['location_id', 'ilike', q]);
    }
    return domain;
  }

  Map<String, dynamic> _readContext(int? uid) => {
    'lang': 'en_US',
    'tz': 'Asia/Calcutta',
    'uid': uid,
  };

  Future<List<ReplenishmentOrderpoint>> fetchOrderpoints({
    required List<dynamic> domain,
    int? limit = 80,
    int offset = 0,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.warehouse.orderpoint',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': [],
        if (limit != null) 'limit': limit,
        'offset': offset,
        'order': 'product_id, location_id, id',
        'context': _readContext(session?.userId),
        'domain': domain,
      },
    });
    final list = (result as List).cast<Map<String, dynamic>>();
    return list.map((e) => ReplenishmentOrderpoint.fromJson(e)).toList();
  }

  Future<int> getCount({required List<dynamic> domain}) async {
    final session = await OdooSessionManager.getCurrentSession();
    final res = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.warehouse.orderpoint',
      'method': 'search_count',
      'args': [domain],
      'kwargs': {'context': _readContext(session?.userId)},
    });
    return (res as num).toInt();
  }

  /// Counts the orderpoints matching [domain] per value of [groupByField],
  /// on the server, so the groups cover every record and not just one page.
  ///
  /// `product_category_id` is stored on 16-18 but a plain related field on
  /// 19, where it cannot be grouped on directly; there the category is
  /// grouped through the product instead.
  Future<List<ReplenishmentGroup>> fetchGroups({
    required List<dynamic> domain,
    required String groupByField,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    Future<dynamic> readGroup(String field) => OdooReadGroup.counts(
      model: 'stock.warehouse.orderpoint',
      domain: domain,
      groupBy: field,
      context: _readContext(session?.userId),
    );

    String field = groupByField;
    dynamic result;
    try {
      result = await readGroup(field);
    } catch (_) {
      if (groupByField != 'product_category_id') rethrow;
      field = 'product_id.categ_id';
      result = await readGroup(field);
    }

    final groups = <ReplenishmentGroup>[];
    if (result is List) {
      for (final g in result) {
        if (g is! Map) continue;
        final raw = g[field];
        final value = raw is List && raw.isNotEmpty ? raw[0] : false;
        final label = raw is List && raw.length > 1
            ? raw[1].toString()
            : _undefinedLabel(groupByField);
        groups.add(
          ReplenishmentGroup(
            key: '$groupByField:$value',
            label: label,
            value: value,
            count: (g['__count'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return groups;
  }

  static String _undefinedLabel(String field) {
    switch (field) {
      case 'warehouse_id':
        return 'No Warehouse';
      case 'location_id':
        return 'No Location';
      case 'product_category_id':
        return 'No Category';
      default:
        return 'No Product';
    }
  }

  /// Runs Odoo's "Order" button (`action_replenish`) and returns the name of
  /// the order it generated (e.g. `P00012`), or null when Odoo reports none.
  ///
  /// On 17, 18 and 19 a single-record call answers with a
  /// `display_notification` client action whose first link is the order
  /// created. A procurement failure (no route, no vendor, ...) is raised as a
  /// `RedirectWarning` carrying Odoo's own reason — see
  /// `ReplenishmentError.from`.
  Future<String?> actionReplenish({required List<int> ids}) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.warehouse.orderpoint',
      'method': 'action_replenish',
      'args': [ids],
      'kwargs': {'context': _context()},
    });
    return _generatedOrderName(result);
  }

  /// Runs Odoo's "Automate" button (`action_replenish_auto`): sets the
  /// orderpoint's trigger to `auto` and orders now. Both happen in one
  /// transaction, so when the order fails the trigger is not changed either.
  Future<String?> actionReplenishAuto({required List<int> ids}) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.warehouse.orderpoint',
      'method': 'action_replenish_auto',
      'args': [ids],
      'kwargs': {'context': _context()},
    });
    return _generatedOrderName(result);
  }

  // The same lang/tz this service has always sent. The web client's
  // `params` / `debug` / `actionStack` entries are deliberately gone: they
  // describe the browser's URL state and mean nothing over RPC.
  Map<String, dynamic> _context() => {'lang': 'en_US', 'tz': 'Asia/Calcutta'};

  static String? _generatedOrderName(dynamic result) {
    if (result is! Map) return null;
    final params = result['params'];
    if (params is! Map) return null;
    final links = params['links'];
    if (links is List && links.isNotEmpty && links.first is Map) {
      final label = (links.first as Map)['label']?.toString();
      if (label != null && label.isNotEmpty && label != 'false') return label;
    }
    return null;
  }

  /// Runs Odoo's Snooze wizard (`stock.orderpoint.snooze`) for [ids].
  ///
  /// On 17, 18 and 19 the wizard fills `snoozed_until` from
  /// `predefined_date` in an `@api.onchange` — which only ever runs in the
  /// web client's form, never on an RPC `create`/`write`. Sending just
  /// `predefined_date` therefore left `snoozed_until` empty, and
  /// `action_snooze` wrote that empty date onto the orderpoints: every
  /// 1 Day / 1 Week / 1 Month snooze actually *cleared* the snooze. The date
  /// is computed here exactly as that onchange computes it, and sent along.
  ///
  /// Returns the date the orderpoints are snoozed until.
  Future<DateTime> snoozeOrderpoints({
    required List<int> ids,
    required String predefinedDate,
    DateTime? customDate,
  }) async {
    final until = snoozeDateFor(predefinedDate, customDate: customDate);
    final context = {
      'lang': 'en_US',
      'tz': 'Asia/Calcutta',
      'active_model': 'stock.warehouse.orderpoint',
      'active_ids': ids,
    };

    final created = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.orderpoint.snooze',
      'method': 'create',
      'args': [
        {
          'orderpoint_ids': [
            [6, 0, ids],
          ],
          'predefined_date': predefinedDate,
          'snoozed_until': _odooDate(until),
        },
      ],
      'kwargs': {'context': context},
    });
    final int wizardId = created is num
        ? created.toInt()
        : int.parse(created.toString());

    await OdooSessionManager.callKwWithCompany({
      'model': 'stock.orderpoint.snooze',
      'method': 'action_snooze',
      'args': [
        [wizardId],
      ],
      'kwargs': {'context': context},
    });
    return until;
  }

  /// The date the wizard's `_onchange_predefined_date` would pick: today
  /// plus 1 day / 1 week / 1 month (the month clamped to its last day, as
  /// `dateutil.relativedelta` does — Jan 31 + 1 month is Feb 28/29), or the
  /// custom date as given.
  static DateTime snoozeDateFor(String predefinedDate, {DateTime? customDate}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (predefinedDate) {
      case 'day':
        return DateTime(today.year, today.month, today.day + 1);
      case 'week':
        return DateTime(today.year, today.month, today.day + 7);
      case 'month':
        final lastDayOfNextMonth = DateTime(today.year, today.month + 2, 0).day;
        final day = today.day > lastDayOfNextMonth
            ? lastDayOfNextMonth
            : today.day;
        return DateTime(today.year, today.month + 1, day);
      case 'custom':
        if (customDate == null) {
          throw ArgumentError('A custom snooze needs a date');
        }
        return DateTime(customDate.year, customDate.month, customDate.day);
      default:
        throw ArgumentError('Unknown snooze option: $predefinedDate');
    }
  }

  static String _odooDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The internal locations an orderpoint of [companyId] can be moved to —
  /// Odoo's Location column checks the company, so other companies' locations
  /// would be rejected on save.
  Future<List<Map<String, dynamic>>> fetchLocations({int? companyId}) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.location',
      'method': 'search_read',
      'args': [
        [
          ['usage', '=', 'internal'],
          if (companyId != null)
            [
              'company_id',
              'in',
              [companyId, false],
            ],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'complete_name'],
        'order': 'complete_name asc',
      },
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateOrderpointValues({
    required int id,
    double? minQty,
    double? maxQty,
    double? manualToOrderQty,
    int? locationId,
  }) async {
    final Map<String, dynamic> vals = {};
    if (locationId != null) vals['location_id'] = locationId;
    if (minQty != null) vals['product_min_qty'] = minQty;
    if (maxQty != null) vals['product_max_qty'] = maxQty;
    if (manualToOrderQty != null)
      vals['qty_to_order_manual'] = manualToOrderQty;

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

  Future<void> updateManualToOrderQty({
    required int id,
    required double qty,
  }) async {
    await updateOrderpointValues(id: id, manualToOrderQty: qty);
  }
}
