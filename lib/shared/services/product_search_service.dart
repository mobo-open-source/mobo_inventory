import 'package:flutter/foundation.dart';
import '../../core/services/odoo_session_manager.dart';

/// Service for performing global product searches across the Odoo catalog.
class ProductSearchService {
  Future<List<Map<String, dynamic>>> fetchProducts({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    bool storableOnly = true,
  }) async {
    try {
      List<dynamic> domain = [];

      if (storableOnly) {
        domain.add('|');
        domain.add(['type', '=', 'product']);
        domain.add(['type', '=', 'consu']);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add('|');
        domain.add(['default_code', 'ilike', searchQuery]);
        domain.add(['barcode', 'ilike', searchQuery]);
      }

      if (kDebugMode) {}

      final result = await OdooSessionManager.safeCallKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'display_name',
            'default_code',
            'barcode',
            'uom_id',
            'qty_available',
            'virtual_available',
            'type',
            'list_price',
            'standard_price',
            'categ_id',
            'image_128',
          ],
          'limit': limit,
          'offset': offset,
          'order': 'name asc',
        },
      });

      final products = (result as List).cast<Map<String, dynamic>>();

      if (kDebugMode) {}

      return products;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getProductCount({
    String? searchQuery,
    bool storableOnly = true,
  }) async {
    try {
      List<dynamic> domain = [];

      if (storableOnly) {
        domain.add('|');
        domain.add(['type', '=', 'product']);
        domain.add(['type', '=', 'consu']);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add('|');
        domain.add(['name', 'ilike', searchQuery]);
        domain.add('|');
        domain.add(['default_code', 'ilike', searchQuery]);
        domain.add(['barcode', 'ilike', searchQuery]);
      }

      final result = await OdooSessionManager.safeCallKw({
        'model': 'product.product',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      return result as int;
    } catch (e) {
      return 0;
    }
  }
}
