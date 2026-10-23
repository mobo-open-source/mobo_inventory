import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/picking_model.dart';
import '../../../core/odoo/odoo_read_group.dart';

class PickingService {
  PickingService({this.posOrders = false});

  /// Lists only Point of Sale's pickings (the PoS Orders card's list)
  /// instead of leaving them out of an outgoing list.
  final bool posOrders;

  static String _getCacheKey(String pickingTypeCode) =>
      'picking_${pickingTypeCode}_data';
  static String _getGroupCacheKey(String pickingTypeCode, String groupBy) =>
      'picking_${pickingTypeCode}_group_$groupBy';

  Future<List<Picking>> loadCachedPickings(String pickingTypeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_getCacheKey(pickingTypeCode));
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cached);
        return data
            .map((e) => Picking.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {}
    return [];
  }

  Future<void> cachePickings(
    String pickingTypeCode,
    List<Picking> pickings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = pickings.map((p) => p.toJson()).toList();
      await prefs.setString(_getCacheKey(pickingTypeCode), jsonEncode(data));
    } catch (e) {}
  }

  Future<Map<String, int>> loadCachedGroupSummary(
    String pickingTypeCode,
    String groupBy,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(
        _getGroupCacheKey(pickingTypeCode, groupBy),
      );
      if (cached != null && cached.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(cached);
        return data.map((key, value) => MapEntry(key, value as int));
      }
    } catch (e) {}
    return {};
  }

  Future<void> cacheGroupSummary(
    String pickingTypeCode,
    String groupBy,
    Map<String, int> summary,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _getGroupCacheKey(pickingTypeCode, groupBy),
        jsonEncode(summary),
      );
    } catch (e) {}
  }

  Future<void> clearCache(String pickingTypeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getCacheKey(pickingTypeCode));

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('picking_${pickingTypeCode}_group_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {}
  }

  Future<OdooClient?> _getClient() async {
    try {
      return await OdooSessionManager.getClientEnsured();
    } catch (_) {
      return null;
    }
  }

  /// What Odoo's Inventory Overview counts as "To Process" for an operation
  /// type (`stock.picking.type.count_picking_ready`): its pickings that are
  /// Ready (`assigned`) — neither draft nor still waiting.
  ///
  /// The dashboard's Receipts, Delivery Orders and Internal Transfers counts
  /// and the lists those cards open both filter by these states, so a card's
  /// number is always the total of the list it opens.
  static const List<String> toProcessStates = ['assigned'];

  /// The Point of Sale operation types: each warehouse's `pos_type_id`
  /// ("PoS Orders"), added by Odoo's `pos_stock` module (`point_of_sale`
  /// before Odoo 20). Their pickings are outgoing too, but Odoo's Inventory
  /// Overview counts them on a PoS Orders card of their own, not under
  /// Delivery Orders.
  ///
  /// Empty without Point of Sale, or when warehouses can't be read.
  static Future<List<int>> posPickingTypeIds() async {
    try {
      final fields = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'fields_get',
        'args': [
          ['pos_type_id'],
        ],
        'kwargs': {
          'attributes': ['type'],
        },
      });
      if (fields is! Map || !fields.containsKey('pos_type_id')) return const [];

      final rows = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'search_read',
        'args': [
          [
            ['pos_type_id', '!=', false],
          ],
        ],
        'kwargs': {
          'fields': ['pos_type_id'],
        },
      });
      if (rows is! List) return const [];
      return {
        for (final row in rows)
          if (row is Map && row['pos_type_id'] is List)
            (row['pos_type_id'] as List).first as int,
      }.toList();
    } catch (_) {
      return const [];
    }
  }

  /// [posPickingTypeIds], looked up once per service (one per list).
  Future<List<int>>? _posTypeIds;

  /// The operation types a list of [pickingTypeCode] leaves out: Delivery
  /// Orders shows no PoS orders, as Odoo counts those apart.
  Future<List<int>> _excludedTypeIds(String pickingTypeCode) {
    if (posOrders || pickingTypeCode != 'outgoing') {
      return Future.value(const []);
    }
    return _posTypeIds ??= posPickingTypeIds();
  }

  /// The operation types a PoS Orders list is limited to; null (no limit)
  /// for any other list.
  Future<List<int>?> _onlyTypeIds() async {
    if (!posOrders) return null;
    return _posTypeIds ??= posPickingTypeIds();
  }

  /// The `stock.picking` domain for one operation type and the list
  /// filters. Shared by the lists below and the dashboard's counts.
  ///
  /// [pickingTypeIds] narrows it to those operation types (the PoS Orders
  /// card); [excludedPickingTypeIds] leaves those out (Delivery Orders
  /// without the PoS ones).
  static List<dynamic> buildDomain({
    required String pickingTypeCode,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? pickingTypeIds,
    List<int> excludedPickingTypeIds = const [],
  }) {
    final domain = <dynamic>[];

    domain.add(['picking_type_code', '=', pickingTypeCode]);
    if (pickingTypeIds != null) {
      domain.add(['picking_type_id', 'in', pickingTypeIds]);
    }
    if (excludedPickingTypeIds.isNotEmpty) {
      domain.add(['picking_type_id', 'not in', excludedPickingTypeIds]);
    }

    if (states != null && states.isNotEmpty) {
      if (states.length == 1) {
        domain.add(['state', '=', states.first]);
      } else {
        for (int i = 0; i < states.length - 1; i++) {
          domain.add('|');
        }
        for (final s in states) {
          domain.add(['state', '=', s]);
        }
      }
    }

    if (startDate != null) {
      domain.add(['scheduled_date', '>=', startDate.toIso8601String()]);
    }
    if (endDate != null) {
      domain.add(['scheduled_date', '<=', endDate.toIso8601String()]);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      domain.add('|');
      domain.add(['name', 'ilike', searchQuery]);
      domain.add('|');
      domain.add(['origin', 'ilike', searchQuery]);
      domain.add(['partner_id', 'ilike', searchQuery]);
    }

    return domain;
  }

  Future<List<Picking>> fetchPickings({
    required String pickingTypeCode,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
    // A group's own domain from [fetchGroupSummary]; replaces the filters.
    List<dynamic>? domainOverride,
  }) async {
    final client = await _getClient();
    if (client == null) return [];

    final domain =
        domainOverride ??
        buildDomain(
          pickingTypeCode: pickingTypeCode,
          searchQuery: searchQuery,
          states: states,
          startDate: startDate,
          endDate: endDate,
          pickingTypeIds: await _onlyTypeIds(),
          excludedPickingTypeIds: await _excludedTypeIds(pickingTypeCode),
        );

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'state',
            'origin',
            'partner_id',
            'picking_type_id',
            'picking_type_code',
            'scheduled_date',
          ],
          'limit': limit,
          'offset': offset,
          'order': 'scheduled_date desc',
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((e) => Picking.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getPickingCount({
    required String pickingTypeCode,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final client = await _getClient();
    if (client == null) return 0;

    final domain = buildDomain(
      pickingTypeCode: pickingTypeCode,
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
      pickingTypeIds: await _onlyTypeIds(),
      excludedPickingTypeIds: await _excludedTypeIds(pickingTypeCode),
    );

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return result as int;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> fetchGroupSummary({
    required String pickingTypeCode,
    required String groupByField,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    // Filled with each group's Odoo domain, keyed like the returned map.
    Map<String, List<dynamic>>? domainsOut,
  }) async {
    final client = await _getClient();
    if (client == null) return {};

    final domain = buildDomain(
      pickingTypeCode: pickingTypeCode,
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
      pickingTypeIds: await _onlyTypeIds(),
      excludedPickingTypeIds: await _excludedTypeIds(pickingTypeCode),
    );

    try {
      final result = await OdooReadGroup.counts(
        model: 'stock.picking',
        domain: domain,
        groupBy: groupByField,
      );

      final map = <String, int>{};
      for (final group in result) {
        final key = _extractGroupKey(group, groupByField);
        final count = (group['__count'] ?? 0) as int;
        map[key] = count;
        final rawDomain = group['__domain'];
        domainsOut?[key] = rawDomain is List
            ? List<dynamic>.from(rawDomain)
            : [
                ...domain,
                [groupByField, '=', group[groupByField] ?? false],
              ];
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  /// What a group is called on screen. Odoo returns selection fields as
  /// their raw key — priority `'0'` / `'1'`, state `'assigned'` — which
  /// meant nothing to a user.
  String _extractGroupKey(Map group, String groupByField) {
    final value = group[groupByField];
    if (value == null || value == false) {
      if (groupByField == 'priority') return 'Normal';
      if (groupByField.contains('date')) return 'No Date';
      return 'Not Set';
    }
    if (value is List && value.length > 1) return value[1].toString();
    switch (groupByField) {
      case 'priority':
        return value.toString() == '1' ? 'Urgent' : 'Normal';
      case 'state':
        return _stateLabels[value.toString()] ?? value.toString();
    }
    return value.toString();
  }

  static const Map<String, String> _stateLabels = {
    'draft': 'Draft',
    'waiting': 'Waiting Another Operation',
    'confirmed': 'Waiting',
    'assigned': 'Ready',
    'done': 'Done',
    'cancel': 'Cancelled',
  };
}
