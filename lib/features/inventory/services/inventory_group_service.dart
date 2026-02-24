import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/inventory_product.dart';

/// Service for fetching grouped product data (e.g., by category or type) from Odoo.
class InventoryGroupService {
  /// Fetches a summary of counts for different groups based on the [groupByField].
  Future<Map<String, int>> fetchGroupSummary({
    required String groupByField,
    String? searchQuery,
    List<String>? categories,
    bool? inStockOnly,
    String? productType,
    bool? isStorable,
    bool? availableInPos,
    bool? saleOk,
    bool? purchaseOk,
    bool? hasActivityException,
    bool? isActive,
    bool? hasNegativeStock,
  }) async {
    try {
      List<dynamic> domain = [];

      if (categories != null && categories.isNotEmpty) {
        if (categories.length == 1) {
          domain.add(['categ_id.name', '=', categories.first]);
        } else {
          for (int i = 0; i < categories.length - 1; i++) {
            domain.add('|');
          }
          for (final cat in categories) {
            domain.add(['categ_id.name', '=', cat]);
          }
        }
      }

      if (inStockOnly == true) {
        domain.add(['qty_available', '>', 0]);
      } else if (inStockOnly == false) {
        domain.add(['qty_available', '<=', 0]);
      }

      if (productType != null) {
        domain.add(['type', '=', productType]);
      }

      if (availableInPos == true) {
        domain.add(['available_in_pos', '=', true]);
      }

      if (saleOk == true) {
        domain.add(['sale_ok', '=', true]);
      }

      if (purchaseOk == true) {
        domain.add(['purchase_ok', '=', true]);
      }

      if (hasActivityException == true) {
        domain.add(['activity_exception_decoration', '!=', false]);
      }

      if (isActive == false) {
        domain.add(['active', '=', false]);
      }

      if (hasNegativeStock == true) {
        domain.add('|');
        domain.add(['qty_available', '>', 0]);
        domain.add(['virtual_available', '<', 0]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add('|');
        domain.add(['default_code', 'ilike', searchQuery]);
        domain.add(['barcode', 'ilike', searchQuery]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'read_group',
        'args': [domain],
        'kwargs': {
          'fields': ['id'],
          'groupby': [groupByField],
          'lazy': false,
          'context': {'bin_size': true, 'default_is_storable': true},
        },
      });

      final groupSummary = <String, int>{};

      if (result is List) {
        for (final group in result) {
          if (group is Map) {
            final groupKey = _getGroupKeyFromReadGroup(group, groupByField);
            final count = (group['__count'] ?? 0) as int;
            groupSummary[groupKey] = count;
          }
        }
      }

      return groupSummary;
    } catch (e) {
      return {};
    }
  }

  String _getGroupKeyFromReadGroup(
    Map<dynamic, dynamic> group,
    String groupByField,
  ) {
    try {
      final value = group[groupByField];

      if (groupByField == 'categ_id') {
        if (value is List && value.length >= 2) {
          return value[1].toString();
        }
        return 'Uncategorized';
      } else if (groupByField == 'type') {
        if (value == 'product') return 'Storable Product';
        if (value == 'consu') return 'Consumable';
        if (value == 'service') return 'Service';
        return value?.toString() ?? 'Unknown';
      } else if (groupByField == 'pos_categ_ids') {
        if (value is List && value.length >= 2) {
          return value[1].toString();
        }
        return 'No POS Category';
      }

      return value?.toString() ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  List<dynamic> buildGroupDomain(String groupKey, String groupByField) {
    try {
      switch (groupByField) {
        case 'categ_id':
          if (groupKey == 'Uncategorized') {
            return [
              ['categ_id', '=', false],
            ];
          }
          return [
            ['categ_id.name', '=', groupKey],
          ];

        case 'type':
          String odooValue;
          switch (groupKey) {
            case 'Consumable':
              odooValue = 'consu';
              break;
            case 'Service':
              odooValue = 'service';
              break;
            case 'Storable Product':
              odooValue = 'product';
              break;
            default:
              odooValue = groupKey.toLowerCase();
          }
          return [
            ['type', '=', odooValue],
          ];

        case 'pos_categ_ids':
          if (groupKey == 'No POS Category') {
            return [
              ['pos_categ_ids', '=', false],
            ];
          }
          return [
            ['pos_categ_ids.name', '=', groupKey],
          ];

        default:
          if (groupKey == 'Unknown') {
            return [
              [groupByField, '=', false],
            ];
          }
          return [
            [groupByField, '=', groupKey],
          ];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<InventoryProduct>> fetchGroupProducts({
    required String groupKey,
    required String groupByField,
    String? searchQuery,
    List<String>? categories,
    bool? inStockOnly,
    String? productType,
    bool? isStorable,
    bool? availableInPos,
    bool? saleOk,
    bool? purchaseOk,
    bool? hasActivityException,
    bool? isActive,
    bool? hasNegativeStock,
    int limit = 80,
    int offset = 0,
  }) async {
    try {
      List<dynamic> domain = [];

      final groupDomain = buildGroupDomain(groupKey, groupByField);
      domain.addAll(groupDomain);

      if (categories != null && categories.isNotEmpty) {
        if (categories.length == 1) {
          domain.add(['categ_id.name', '=', categories.first]);
        } else {
          for (int i = 0; i < categories.length - 1; i++) {
            domain.add('|');
          }
          for (final cat in categories) {
            domain.add(['categ_id.name', '=', cat]);
          }
        }
      }

      if (inStockOnly == true) {
        domain.add(['qty_available', '>', 0]);
      } else if (inStockOnly == false) {
        domain.add(['qty_available', '<=', 0]);
      }

      if (productType != null) {
        domain.add(['type', '=', productType]);
      }

      if (availableInPos == true) {
        domain.add(['available_in_pos', '=', true]);
      }

      if (saleOk == true) {
        domain.add(['sale_ok', '=', true]);
      }

      if (purchaseOk == true) {
        domain.add(['purchase_ok', '=', true]);
      }

      if (hasActivityException == true) {
        domain.add(['activity_exception_decoration', '!=', false]);
      }

      if (isActive == false) {
        domain.add(['active', '=', false]);
      }

      if (hasNegativeStock == true) {
        domain.add('|');
        domain.add(['qty_available', '>', 0]);
        domain.add(['virtual_available', '<', 0]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add('|');
        domain.add(['default_code', 'ilike', searchQuery]);
        domain.add(['barcode', 'ilike', searchQuery]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': [],
          'limit': limit,
          'offset': offset,
          'context': {'bin_size': true, 'default_is_storable': true},
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((json) => InventoryProduct.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
