import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/warehouse_model.dart';

class WarehouseService {

  static const String _cacheKeyData = 'warehouse_data';
  static String _detailKey(int id) => 'warehouse_detail_$id';

  Future<List<Warehouse>> loadCachedWarehouses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKeyData);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> data = jsonDecode(cached);
        return data
            .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
          }
    return [];
  }

  Future<void> cacheWarehouses(List<Warehouse> warehouses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = warehouses.map((w) => w.toJson()).toList();
      await prefs.setString(_cacheKeyData, jsonEncode(data));
    } catch (e) {
          }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyData);
    } catch (e) {
          }
  }

  Future<List<Warehouse>> fetchWarehouses({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    bool? hasStockLocation,
    bool? hasCode,
  }) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();

      final List<dynamic> domain = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['code', 'ilike', searchQuery]);
      }

      if (hasStockLocation == true) {
        domain.add(['lot_stock_id', '!=', false]);
      }

      if (hasCode == true) {
        domain.add(['code', '!=', '']);
      }

      try {

      } catch (_) {}

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'code', 'company_id', 'lot_stock_id'],
          'limit': limit,
          'offset': offset,
          'order': 'name asc',
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((json) => Warehouse.fromJson(json)).toList();
    } catch (e) {
            rethrow;
    }
  }

  Future<int> getWarehouseCount({String? searchQuery, bool? hasStockLocation, bool? hasCode}) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();

      final List<dynamic> domain = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add(['code', 'ilike', searchQuery]);
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
        'model': 'stock.warehouse',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      return result as int;
    } catch (e) {
            rethrow;
    }
  }

  Future<int> createWarehouse({
    required String name,
    required String code,
    required int companyId,
    int? partnerId,
    bool active = true,
  }) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final payload = <String, dynamic>{
        'name': name,
        'active': active,
        'code': code,
        'company_id': companyId,
      };
      if (partnerId != null) payload['partner_id'] = partnerId;

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'create',
        'args': [payload],
        'kwargs': {},
      });
      return (result as int);
    } catch (e) {
            rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCompanies() async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          []
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
          'limit': 100,
        },
      });
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchCompanyDetail(int companyId) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.company',
        'method': 'read',
        'args': [
          [companyId],
          ['name', 'partner_id']
        ],
        'kwargs': {},
      });
      if (res is List && res.isNotEmpty) return (res.first as Map<String, dynamic>);
      return null;
    } catch (e) {
            rethrow;
    }
  }

  Future<int> getWarehouseCountByCompany(int companyId) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'search_count',
        'args': [
          [
            ['company_id', '=', companyId]
          ]
        ],
        'kwargs': {},
      });
      return result as int;
    } catch (e) {
            rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchWarehouseDetail(int id) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'read',
        'args': [
          [id],
          [
            'name',
            'code',
            'company_id',
            'partner_id',
            'display_name',
          ]
        ],
        'kwargs': {},
      });
      if (res is List && res.isNotEmpty) return (res.first as Map<String, dynamic>);
      return null;
    } catch (e) {
            rethrow;
    }
  }

  Future<void> cacheWarehouseDetail(int id, Map<String, dynamic> detail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_detailKey(id), jsonEncode(detail));
    } catch (e) {
          }
  }

  Future<Map<String, dynamic>?> loadCachedWarehouseDetail(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_detailKey(id));
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      return data;
    } catch (e) {
            return null;
    }
  }
}
