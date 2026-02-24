import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/picking_model.dart';

class PickingService {

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
    } catch (e) {
          }
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
    } catch (e) {
          }
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
    } catch (e) {
          }
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
    } catch (e) {
          }
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
    } catch (e) {
          }
  }

  Future<OdooClient?> _getClient() async {
    try {
      return await OdooSessionManager.getClientEnsured();
    } catch (_) {
      return null;
    }
  }

  List<dynamic> _buildDomain({
    required String pickingTypeCode,
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final domain = <dynamic>[];

    domain.add(['picking_type_code', '=', pickingTypeCode]);

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
  }) async {
    final client = await _getClient();
    if (client == null) return [];

    final domain = _buildDomain(
      pickingTypeCode: pickingTypeCode,
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
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

    final domain = _buildDomain(
      pickingTypeCode: pickingTypeCode,
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
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
  }) async {
    final client = await _getClient();
    if (client == null) return {};

    final domain = _buildDomain(
      pickingTypeCode: pickingTypeCode,
      searchQuery: searchQuery,
      states: states,
      startDate: startDate,
      endDate: endDate,
    );

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'read_group',
        'args': [domain],
        'kwargs': {
          'fields': ['id'],
          'groupby': [groupByField],
          'lazy': false,
        },
      });

      final map = <String, int>{};
      if (result is List) {
        for (final group in result) {
          if (group is Map) {
            final key = _extractGroupKey(group, groupByField);
            final count = (group['__count'] ?? 0) as int;
            map[key] = count;
          }
        }
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
