import 'package:odoo_rpc/odoo_rpc.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/inventory_status.dart';

class InventoryService {
  Future<OdooClient?> _getClient() async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      return client;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isInventoryInstalled() async {
    final client = await _getClient();
    if (client == null) return false;
    try {
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'search_count',
        'args': [[]],
        'kwargs': {},
      });
      return count is int;
    } catch (e) {
      throw Exception(
        'Unable to access the Inventory (stock) module.\nPlease ensure the module is installed and you have permissions to view warehouses.',
      );
    }
  }

  Future<InventoryStatus> checkInventoryStatus() async {
    final client = await _getClient();
    if (client == null) {
      return const InventoryStatus(
        isInstalled: false,
        hasAccess: false,
        message: 'No active session',
      );
    }
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id'],
          'limit': 1,
        },
      });
      return const InventoryStatus(isInstalled: true, hasAccess: true);
    } on OdooException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains("doesn't exist") ||
          msg.contains('unknown model') ||
          msg.contains('missing model')) {
        return const InventoryStatus(
          isInstalled: false,
          hasAccess: false,
          message: 'Inventory (stock) module is not installed on this server.',
        );
      }
      if (msg.contains('accesserror') ||
          msg.contains('permission denied') ||
          msg.contains('access denied')) {
        return const InventoryStatus(
          isInstalled: true,
          hasAccess: false,
          message:
              'You do not have permission to access Inventory. Please contact your administrator.',
        );
      }
      return InventoryStatus(
        isInstalled: false,
        hasAccess: false,
        message: 'Unexpected Odoo error: ${e.message}',
      );
    } catch (e) {
      return InventoryStatus(
        isInstalled: false,
        hasAccess: false,
        message: 'Unexpected error: $e',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses() async {
    final client = await _getClient();
    if (client == null) return [];
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.warehouse',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name', 'code', 'lot_stock_id'],
        'limit': 80,
      },
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchInternalLocations({
    int? warehouseLotStockLocationId,
  }) async {
    final session = await OdooSessionManager.getCurrentSession();
    final client = await _getClient();
    if (session == null || client == null) return [];
    final List<List<dynamic>> domain = [
      ['usage', '=', 'internal'],
    ];
    if (warehouseLotStockLocationId != null) {
      domain.add(['id', 'child_of', warehouseLotStockLocationId]);
    }
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.location',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': domain,
        'fields': ['id', 'name', 'complete_name', 'location_id', 'usage'],
        'limit': 200,
      },
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> findProductByBarcode(String barcode) async {
    final client = await _getClient();
    if (client == null) return null;
    final prod = await OdooSessionManager.callKwWithCompany({
      'model': 'product.product',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['barcode', '=', barcode],
        ],
        'fields': [
          'id',
          'name',
          'default_code',
          'barcode',
          'uom_id',
          'product_tmpl_id',
        ],
        'limit': 1,
      },
    });
    final list = (prod as List).cast<Map<String, dynamic>>();
    if (list.isNotEmpty) return list.first;

    final tmpl = await OdooSessionManager.callKwWithCompany({
      'model': 'product.template',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['barcode', '=', barcode],
        ],
        'fields': ['id', 'name', 'default_code', 'barcode', 'uom_id'],
        'limit': 1,
      },
    });
    final tlist = (tmpl as List).cast<Map<String, dynamic>>();
    if (tlist.isEmpty) return null;

    final tmplId = tlist.first['id'] as int;
    final variant = await OdooSessionManager.callKwWithCompany({
      'model': 'product.product',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['product_tmpl_id', '=', tmplId],
        ],
        'fields': [
          'id',
          'name',
          'default_code',
          'barcode',
          'uom_id',
          'product_tmpl_id',
        ],
        'limit': 1,
      },
    });
    final vlist = (variant as List).cast<Map<String, dynamic>>();
    return vlist.isNotEmpty ? vlist.first : null;
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final client = await _getClient();
    if (client == null) return [];
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'product.product',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          '|',
          '|',
          ['name', 'ilike', query],
          ['default_code', 'ilike', query],
          ['barcode', 'ilike', query],
        ],
        'fields': [
          'id',
          'name',
          'default_code',
          'barcode',
          'uom_id',
          'product_tmpl_id',
        ],
        'limit': 20,
      },
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchQuantsForProduct(
    int productId,
  ) async {
    final client = await _getClient();
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null || client == null) return [];
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.quant',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['product_id', '=', productId],
          ['location_id.usage', '=', 'internal'],
          ['quantity', '>', 0],
        ],
        'fields': [
          'id',
          'product_id',
          'location_id',
          'lot_id',
          'quantity',
          'available_quantity',
          'reserved_quantity',
        ],
        'limit': 200,
      },
    });
    return (result as List).cast<Map<String, dynamic>>();
  }
}
