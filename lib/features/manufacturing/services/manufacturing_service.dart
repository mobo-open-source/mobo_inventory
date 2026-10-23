import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/manufacturing_transfer_model.dart';
import '../../../core/odoo/odoo_compat.dart';
import '../../../core/odoo/odoo_read_group.dart';

class ManufacturingService {
  /// Odoo's Manufacturing Orders menu opens on its "To Do" filter: the
  /// orders still to be worked on. The dashboard's Manufacturing Orders
  /// count and the list that card opens both use these states, so the
  /// card's number is the list's total.
  static const List<String> toDoStates = [
    'draft',
    'confirmed',
    'progress',
    'to_close',
  ];

  // The cache holds the list's default ("To Do") view. The keys changed
  // with that default so a cache of the old unfiltered list isn't shown.
  static const String _cacheKeyData = 'manufacturing_todo_data';
  static const String _groupCacheKeyPrefix = 'manufacturing_todo_group_';
  static String _getGroupCacheKey(String groupBy) =>
      '$_groupCacheKeyPrefix$groupBy';

  Future<List<ManufacturingTransfer>> loadCachedManufacturing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKeyData);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cached);
        return data
            .map(
              (e) => ManufacturingTransfer.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {}
    return [];
  }

  Future<void> cacheManufacturing(List<ManufacturingTransfer> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = items.map((p) => p.toJson()).toList();
      await prefs.setString(_cacheKeyData, jsonEncode(data));
    } catch (e) {}
  }

  Future<Map<String, int>> loadCachedGroupSummary(String groupBy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_getGroupCacheKey(groupBy));
      if (cached != null && cached.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(cached);
        return data.map((key, value) => MapEntry(key, value as int));
      }
    } catch (e) {}
    return {};
  }

  Future<void> cacheGroupSummary(
    String groupBy,
    Map<String, int> summary,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getGroupCacheKey(groupBy), jsonEncode(summary));
    } catch (e) {}
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyData);

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_groupCacheKeyPrefix)) {
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

  /// The `mrp.production` domain for the list filters. Shared by the list
  /// below and the dashboard's counts.
  static List<dynamic> buildDomain({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final domain = <dynamic>[];

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
      domain.add(['create_date', '>=', startDate.toIso8601String()]);
    }
    if (endDate != null) {
      domain.add(['create_date', '<=', endDate.toIso8601String()]);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      domain.add('|');
      domain.add(['name', 'ilike', searchQuery]);
      domain.add('|');
      domain.add(['origin', 'ilike', searchQuery]);
      domain.add(['product_id', 'ilike', searchQuery]);
    }

    return domain;
  }

  Future<List<ManufacturingTransfer>> fetchProductions({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    final client = await _getClient();
    if (client == null) return [];

    final domain = buildDomain(
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
    );

    try {
      final compat = await OdooCompat.current();
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'state',
            'origin',
            'product_id',
            'product_qty',
            compat.mrpProductionUomField,
            'date_start',
            'date_finished',
            'create_date',
          ],
          'limit': limit,
          'offset': offset,

          'order': 'create_date desc',
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((e) => ManufacturingTransfer.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getProductionsCount({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final client = await _getClient();
    if (client == null) return 0;

    final domain = buildDomain(
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
    );

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'mrp.production',
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
    required String groupByField,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final client = await _getClient();
    if (client == null) return {};

    final domain = buildDomain(
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
    );

    try {
      final result = await OdooReadGroup.counts(
        model: 'mrp.production',
        domain: domain,
        groupBy: groupByField,
      );

      final map = <String, int>{};
      for (final group in result) {
        final key = _extractGroupKey(group, groupByField);
        final count = (group['__count'] ?? 0) as int;
        map[key] = count;
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  String _extractGroupKey(Map group, String groupByField) {
    final value = group[groupByField];
    if (value == null || value == false) return 'Undefined';
    if (value is List && value.length > 1) return value[1].toString();
    return value.toString();
  }
}
