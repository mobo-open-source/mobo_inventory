import '../../../core/services/odoo_session_manager.dart';
import '../models/inventory_product.dart';
import '../../../core/odoo/odoo_read_group.dart';
import 'inventory_product_service.dart';

/// Service for fetching grouped product data (e.g., by category or type) from Odoo.
class InventoryGroupService {
  /// Counts the products matching [domain] per value of [groupByField].
  ///
  /// [domainsOut] is filled with each group's own Odoo domain, keyed like the
  /// returned map, for [fetchGroupProducts]. [typeLabels] names the `type`
  /// values as the server does (Odoo 18 calls `consu` "Goods").
  Future<Map<String, int>> fetchGroupSummary({
    required String groupByField,
    required List<dynamic> domain,
    Map<String, List<dynamic>>? domainsOut,
    Map<String, String> typeLabels = const {},
  }) async {
    try {
      final result = await OdooReadGroup.counts(
        model: 'product.product',
        domain: domain,
        groupBy: groupByField,
        context: {'bin_size': true, 'default_is_storable': true},
      );

      final groupSummary = <String, int>{};

      for (final group in result) {
        final groupKey = _getGroupKeyFromReadGroup(
          group,
          groupByField,
          typeLabels,
        );
        final count = (group['__count'] ?? 0) as int;
        groupSummary[groupKey] = count;
        final groupDomain = group['__domain'];
        domainsOut?[groupKey] = groupDomain is List
            ? List<dynamic>.from(groupDomain)
            : [
                ...domain,
                [groupByField, '=', _rawValue(group[groupByField])],
              ];
      }

      return groupSummary;
    } catch (e) {
      return {};
    }
  }

  static dynamic _rawValue(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first;
    return value ?? false;
  }

  String _getGroupKeyFromReadGroup(
    Map<dynamic, dynamic> group,
    String groupByField,
    Map<String, String> typeLabels,
  ) {
    try {
      final value = group[groupByField];

      if (groupByField == 'categ_id') {
        if (value is List && value.length >= 2) {
          return value[1].toString();
        }
        return 'Uncategorized';
      } else if (groupByField == 'type') {
        final label = typeLabels[value?.toString()];
        if (label != null) return label;
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

  /// The products of one group, selected by the group's own [domain] from
  /// [fetchGroupSummary].
  Future<List<InventoryProduct>> fetchGroupProducts({
    required List<dynamic> domain,
    int limit = 80,
    int offset = 0,
  }) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': InventoryProductService.listFields,
          'limit': limit,
          'offset': offset,
          // Like the flat list: image_128 comes back as base64, not a size.
          'context': {'bin_size': false, 'default_is_storable': true},
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((json) => InventoryProduct.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
