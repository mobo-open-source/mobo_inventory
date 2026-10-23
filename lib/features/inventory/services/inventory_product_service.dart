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

  /// Fields every product list reads; [InventoryProduct.fromJson] uses them.
  ///
  /// Without an explicit whitelist, Odoo returns every field on the model —
  /// including every image resolution variant (image_256, image_512,
  /// image_1024, image_1920) as full base64 payloads, since bin_size is
  /// false. Only image_128 is ever read; fetching the rest bloats the
  /// response enough to get the connection dropped mid-stream on slower
  /// links.
  static const List<String> listFields = [
    'id',
    'name',
    'display_name',
    'default_code',
    'barcode',
    'qty_available',
    'virtual_available',
    'incoming_qty',
    'outgoing_qty',
    'free_qty',
    'standard_price',
    'lst_price',
    'uom_id',
    'categ_id',
    'image_128',
  ];

  /// The product list's filters as an Odoo domain; the grouped view uses the
  /// same one.
  ///
  /// [categoryIds] match their sub-categories too (`child_of`), as Odoo's own
  /// category filter does: products sit in leaf categories such as
  /// "Furniture / Office", so a parent like "Furniture" holds none itself.
  /// [isStorable] is the `is_storable` flag Odoo 18 introduced when it folded
  /// the "Storable Product" type into "Goods"; before 18 storable is
  /// [productType] `product`.
  static List<dynamic> buildDomain({
    String? searchQuery,
    List<int>? categoryIds,
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

    if (categoryIds != null && categoryIds.isNotEmpty) {
      domain.add(['categ_id', 'child_of', categoryIds]);
    }

    if (inStockOnly == true) {
      domain.add(['qty_available', '>', 0]);
    } else if (inStockOnly == false) {
      domain.add(['qty_available', '<=', 0]);
    }

    if (productType != null) {
      domain.add(['type', '=', productType]);
    }

    if (isStorable == true) {
      domain.add(['is_storable', '=', true]);
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
    List<int>? categoryIds,
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

    final domain = buildDomain(
      searchQuery: searchQuery,
      categoryIds: categoryIds,
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
          'fields': listFields,
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
    List<int>? categoryIds,
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

    final domain = buildDomain(
      searchQuery: searchQuery,
      categoryIds: categoryIds,
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

  /// Product categories as `id` → full path ("Furniture / Office"), so
  /// sub-categories that share a name stay apart.
  Future<Map<int, String>> fetchCategories() async {
    final client = await _getClient();

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'product.category',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          // `complete_name` is not stored on every release, so it cannot be
          // the server-side order.
          'fields': ['id', 'complete_name'],
          'limit': 200,
        },
      });

      final list = (result as List).cast<Map<String, dynamic>>();
      final entries = [
        for (final cat in list)
          if (cat['id'] is int)
            MapEntry(cat['id'] as int, cat['complete_name']?.toString() ?? ''),
      ]..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
      return Map.fromEntries(entries);
    } catch (e) {
      return {};
    }
  }
}
