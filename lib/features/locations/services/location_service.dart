import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/location_model.dart';

class LocationService {

  static String _cacheKey({int? parentId}) =>
      parentId != null ? 'locations_parent_$parentId' : 'locations_all';

  Future<List<StockLocation>> loadCachedLocations({int? parentId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey(parentId: parentId));
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cached);
        return data
            .map((e) => StockLocation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
          }
    return [];
  }

  Future<void> cacheLocations(List<StockLocation> items, {int? parentId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = items.map((e) => e.toJson()).toList();
      await prefs.setString(_cacheKey(parentId: parentId), jsonEncode(data));
    } catch (e) {
          }
  }

  Future<void> clearCache({int? parentId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (parentId != null) {
        await prefs.remove(_cacheKey(parentId: parentId));
      } else {
        final keys = prefs.getKeys();
        for (final k in keys) {
          if (k.startsWith('locations_')) await prefs.remove(k);
        }
      }
    } catch (e) {
          }
  }

  Future<List<StockLocation>> fetchLocations({
    String? searchQuery,
    String usage = 'internal',
    int? parentId,
    int limit = 30,
    int offset = 0,
  }) async {
    try {

      final List<dynamic> domain = [];

      if (usage.isNotEmpty) {
        domain.add(['usage', '=', usage]);
      }

      if (parentId != null) {
        domain.add(['id', 'child_of', parentId]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['complete_name', 'ilike', searchQuery]);
      }

      try {

      } catch (_) {}

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'complete_name', 'usage', 'location_id'],
          'limit': limit,
          'offset': offset,
          'order': 'complete_name asc',
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((json) => StockLocation.fromJson(json)).toList();
    } catch (e) {
            rethrow;
    }
  }

  Future<int> getLocationsCount({
    String? searchQuery,
    String usage = 'internal',
    int? parentId,
  }) async {
    try {

      final List<dynamic> domain = [];
      if (usage.isNotEmpty) domain.add(['usage', '=', usage]);
      if (parentId != null) domain.add(['id', 'child_of', parentId]);
      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['complete_name', 'ilike', searchQuery]);
      }

      try {
        final currentCompanyId = await OdooSessionManager.getSelectedCompanyId();
        if (currentCompanyId != null) {
          domain.add('|');
          domain.add(['company_id', '=', false]);
          domain.add(['company_id', '=', currentCompanyId]);
        }
      } catch (_) {}

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return result as int;
    } catch (e) {
            rethrow;
    }
  }

  Future<int> createLocation({
    required String name,
    String usage = 'internal',
    int? parentId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'usage': usage,
      };
      if (parentId != null) payload['location_id'] = parentId;

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'create',
        'args': [payload],
        'kwargs': {},
      });
      return (result as int);
    } catch (e) {
            rethrow;
    }
  }
}
