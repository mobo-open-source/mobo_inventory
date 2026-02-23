import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/inventory_product.dart';
import '../repository/inventory_product_repository.dart';

/// Service for fetching and managing product data from Odoo.
class InventoryProductService {
  Future<OdooClient> _getClient() async {
    final client = await OdooSessionManager.getClientEnsured();
    return client;
  }

  List<dynamic> _buildDomain({
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
  }) {
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

    if (isActive == true) {
      domain.add(['active', '=', true]);
    } else if (isActive == false) {
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

    return domain;
  }

  /// Fetches a list of products based on various filters and search queries.
  Future<List<InventoryProduct>> fetchProducts({
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
    final client = await _getClient();
    final session = await OdooSessionManager.getCurrentSession();

    final domain = _buildDomain(
      searchQuery: searchQuery,
      categories: categories,
      inStockOnly: inStockOnly,
      productType: productType,
      isStorable: isStorable,
      availableInPos: availableInPos,
      saleOk: saleOk,
      purchaseOk: purchaseOk,
      hasActivityException: hasActivityException,
      isActive: isActive,
      hasNegativeStock: hasNegativeStock,
    );

    try {
      if (kDebugMode) {
        for (var item in domain) {
          if (item is String && !['|', '&', '!'].contains(item)) {}
        }
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [...domain],
        ],
        'kwargs': {
          'limit': limit,
          'offset': offset,
          'context': {
            'lang': 'en_US',
            'tz': 'Asia/Calcutta',
            'uid': session?.userId,

            'bin_size': false,
            'default_is_storable': true,
          },
        },
      });

      if (kDebugMode) {}
      final list = (result as List).cast<Map<String, dynamic>>();

      if (kDebugMode) {
        for (int i = 0; i < list.length && i < 15; i++) {
          final r = list[i];
        }
      }
      final products = list
          .map((json) => InventoryProduct.fromJson(json))
          .toList();

      try {
        await InventoryProductRepository().replaceCache(products);
      } catch (e) {}
      return products;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getProductCount({
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
    final client = await _getClient();
    final session = await OdooSessionManager.getCurrentSession();

    final domain = _buildDomain(
      searchQuery: searchQuery,
      categories: categories,
      inStockOnly: inStockOnly,
      productType: productType,
      isStorable: isStorable,
      availableInPos: availableInPos,
      saleOk: saleOk,
      purchaseOk: purchaseOk,
      hasActivityException: hasActivityException,
      isActive: isActive,
      hasNegativeStock: hasNegativeStock,
    );

    try {
      if (kDebugMode) {}

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_count',
        'args': [
          [...domain],
        ],
        'kwargs': {
          'context': {
            'lang': 'en_US',
            'tz': 'Asia/Calcutta',
            'uid': session?.userId,
            'bin_size': true,
            'default_is_storable': true,
          },
        },
      });

      if (kDebugMode) {}
      return result as int;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchCategories() async {
    final client = await _getClient();

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.category',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['name'],
          'limit': 100,
          'order': 'name asc',
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      return list.map((cat) => cat['name'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}
