import 'package:flutter/foundation.dart';
import '../../../core/exceptions/inventory_exceptions.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/inventory_adjustment_model.dart';

/// Service for managing inventory adjustments and stock level updates in Odoo.
class AdjustmentService {
  /// Fetches a list of stock quants for inventory adjustment.
  Future<List<InventoryAdjustment>> fetchAdjustments({
    int offset = 0,
    int limit = 20,
    String? searchQuery,
    int? productId,
    int? locationId,
    bool internalLocations = true,
    bool transitLocations = true,
    bool onHand = false,
    bool onHandFlag = false,
    bool quantityPositive = false,
    bool toCount = false,
    bool countedSet = false,
    bool toApply = false,
    bool inStock = false,
    bool conflicts = false,
    bool negativeStock = false,
    bool reservedOnly = false,
    bool mineOnly = false,
    DateTime? incomingDateStart,
    DateTime? incomingDateEnd,
    bool incomingDateToToday = false,
  }) async {
    try {
      List<dynamic> domain = [];

      final usages = <String>[];
      if (internalLocations) usages.add('internal');
      if (transitLocations) usages.add('transit');
      if (usages.isNotEmpty) {
        domain.add(['location_id.usage', 'in', usages]);
      }

      if (productId != null) {
        domain.add(['product_id', '=', productId]);
      } else if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add(['product_id', 'ilike', searchQuery]);
      }

      if (locationId != null) {
        domain.add(['location_id', '=', locationId]);
      }

      if (quantityPositive) {
        domain.add(['quantity', '>', 0]);
      }
      if (negativeStock) {
        domain.add(['quantity', '<', 0]);
      }
      if (onHandFlag) {
        domain.add(['on_hand', '=', true]);
      }
      if (inStock) {
        domain.add(['quantity', '>', 0]);
      }

      if (toApply) {
        domain.add(['inventory_quantity_set', '=', true]);
        domain.add(['inventory_diff_quantity', '!=', 0]);
      } else if (countedSet) {
        domain.add(['inventory_quantity_set', '=', true]);
      } else if (toCount) {
        domain.add(['inventory_quantity_set', '=', false]);
      } else {}
      if (conflicts) domain.add(['is_outdated', '=', true]);
      if (reservedOnly) domain.add(['reserved_quantity', '>', 0]);
      if (mineOnly) {
        final session = await OdooSessionManager.getCurrentSession();
        final uid = session?.userId;
        if (uid != null) {
          domain.add(['user_id', '=', uid]);
        }
      }
      if (incomingDateStart != null) {
        final d =
            "${incomingDateStart.year}-${incomingDateStart.month.toString().padLeft(2, '0')}-${incomingDateStart.day.toString().padLeft(2, '0')}";
        domain.add(['inventory_date', '>=', d]);
      }
      if (incomingDateEnd != null) {
        final d =
            "${incomingDateEnd.year}-${incomingDateEnd.month.toString().padLeft(2, '0')}-${incomingDateEnd.day.toString().padLeft(2, '0')}";
        domain.add(['inventory_date', '<=', d]);
      }
      if (incomingDateToToday) {
        final now = DateTime.now();
        final todayStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        domain.add(['inventory_date', '<=', todayStr]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'web_search_read',
        'args': [],
        'kwargs': {
          'specification': {
            'id': {},
            'product_id': {
              'fields': {'display_name': {}},
            },
            'location_id': {
              'fields': {'display_name': {}},
            },
            'lot_id': {
              'fields': {'display_name': {}},
            },
            'quantity': {},
            'inventory_quantity': {},
            'inventory_quantity_set': {},
            'inventory_diff_quantity': {},
            'inventory_date': {},
            'user_id': {
              'fields': {'display_name': {}},
            },
            'tracking': {},
            'is_outdated': {},
            'available_quantity': {},
          },
          'offset': offset,
          'order':
              'location_id ASC, inventory_date ASC, product_id ASC, package_id ASC, lot_id ASC, owner_id ASC',
          'limit': limit,
          'context': {
            'bin_size': true,
            'mail_notify_force_send': false,
            'inventory_mode': true,
            'no_at_date': true,
          },
          'count_limit': 10001,
          'domain': domain,
        },
      });

      if (result is Map<String, dynamic>) {
        final records = result['records'] as List?;
        final totalLength = result['length'] as int?;

        if (records == null) {
          return [];
        }

        int negQtyCount = 0;
        int negAvailCount = 0;
        for (int i = 0; i < records.length && i < 20; i++) {
          final item = records[i] as Map<String, dynamic>;
          final rawId = item['id'];
          String? rawProd;
          if (item['product_id'] is List) {
            final l = item['product_id'] as List;
            rawProd = l.length > 1
                ? l[1]?.toString()
                : l.isNotEmpty
                ? l[0]?.toString()
                : null;
          } else if (item['product_id'] is Map) {
            rawProd = (item['product_id'] as Map)['display_name']?.toString();
          } else {
            rawProd = item['product_id']?.toString();
          }
          String? rawLoc;
          if (item['location_id'] is List) {
            final l = item['location_id'] as List;
            rawLoc = l.length > 1
                ? l[1]?.toString()
                : l.isNotEmpty
                ? l[0]?.toString()
                : null;
          } else if (item['location_id'] is Map) {
            rawLoc = (item['location_id'] as Map)['display_name']?.toString();
          } else {
            rawLoc = item['location_id']?.toString();
          }
          final qty = (item['quantity'] is num)
              ? (item['quantity'] as num).toDouble()
              : null;
          final avail = (item['available_quantity'] is num)
              ? (item['available_quantity'] as num).toDouble()
              : null;
          if (qty != null && qty < 0) negQtyCount++;
          if (avail != null && avail < 0) negAvailCount++;
        }
        if (records.isNotEmpty) {}

        final rawIds = records.map((item) => item['id']).toList();
        final uniqueRawIds = rawIds.toSet().toList();
        if (rawIds.length != uniqueRawIds.length) {}

        final adjustments = records
            .map(
              (item) =>
                  InventoryAdjustment.fromJson(item as Map<String, dynamic>),
            )
            .toList();

        int negParsedOnHand = 0;
        for (int i = 0; i < adjustments.length && i < 20; i++) {
          final a = adjustments[i];
          if (a.onHandQuantity < 0) negParsedOnHand++;
        }
        if (adjustments.isNotEmpty) {}

        final seen = <int>{};
        final uniqueAdjustments = adjustments.where((adj) {
          if (adj.id == null) return true;
          if (seen.contains(adj.id)) {
            return false;
          }
          seen.add(adj.id!);
          return true;
        }).toList();

        if (uniqueAdjustments.length != adjustments.length) {}

        return uniqueAdjustments;
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getAdjustmentCount({
    String? searchQuery,
    int? productId,
    int? locationId,
    bool internalLocations = true,
    bool transitLocations = true,
    bool onHand = false,
    bool onHandFlag = false,
    bool quantityPositive = false,
    bool toCount = false,
    bool countedSet = false,
    bool toApply = false,
    bool inStock = false,
    bool conflicts = false,
    bool negativeStock = false,
    bool reservedOnly = false,
    bool mineOnly = false,
    DateTime? incomingDateStart,
    DateTime? incomingDateEnd,
    bool incomingDateToToday = false,
  }) async {
    try {
      final usages = <String>[];
      if (internalLocations) usages.add('internal');
      if (transitLocations) usages.add('transit');
      List<dynamic> domain = [];
      if (usages.isNotEmpty) {
        domain.add(['location_id.usage', 'in', usages]);
      }
      if (productId != null) {
        domain.add(['product_id', '=', productId]);
      } else if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add(['product_id', 'ilike', searchQuery]);
      }
      if (locationId != null) {
        domain.add(['location_id', '=', locationId]);
      }
      if (onHand) {
        domain.add(['quantity', '>', 0]);
      }
      if (quantityPositive) {
        domain.add(['quantity', '>', 0]);
      }
      if (negativeStock) {
        domain.add(['quantity', '<', 0]);
      }
      if (onHandFlag) {
        domain.add(['on_hand', '=', true]);
      }
      if (inStock) {
        domain.add(['quantity', '>', 0]);
      }
      if (toCount) {
        domain.add(['inventory_quantity_set', '=', false]);
      }
      if (countedSet) {
        domain.add(['inventory_quantity_set', '=', true]);
      }
      if (toApply) {
        domain.add(['inventory_quantity_set', '=', true]);
        domain.add(['inventory_diff_quantity', '!=', 0]);
      }

      if (!(toApply || countedSet || toCount)) {}
      if (conflicts) domain.add(['is_outdated', '=', true]);
      if (reservedOnly) domain.add(['reserved_quantity', '>', 0]);
      if (mineOnly) {
        final session = await OdooSessionManager.getCurrentSession();
        final uid = session?.userId;
        if (uid != null) {
          domain.add(['user_id', '=', uid]);
        }
      }
      if (incomingDateStart != null) {
        final d =
            "${incomingDateStart.year}-${incomingDateStart.month.toString().padLeft(2, '0')}-${incomingDateStart.day.toString().padLeft(2, '0')}";
        domain.add(['inventory_date', '>=', d]);
      }
      if (incomingDateEnd != null) {
        final d =
            "${incomingDateEnd.year}-${incomingDateEnd.month.toString().padLeft(2, '0')}-${incomingDateEnd.day.toString().padLeft(2, '0')}";
        domain.add(['inventory_date', '<=', d]);
      }
      if (incomingDateToToday) {
        final now = DateTime.now();
        final todayStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        domain.add(['inventory_date', '<=', todayStr]);
      }

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {
          'context': {
            'inventory_mode': true,
            'no_at_date': true,
            'from_mobile': true,
          },
        },
      });

      return result is int ? result : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> updateInventoryQuantity({
    required int quantId,
    required double countedQuantity,
  }) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'write',
        'args': [
          [quantId],
          {
            'inventory_quantity': countedQuantity,
            'inventory_quantity_set': true,
          },
        ],
        'kwargs': {
          'context': {'inventory_mode': true, 'no_at_date': true},
        },
      });

      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> applyAdjustment(int quantId) async {
    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'action_apply_inventory',
        'args': [
          [quantId],
        ],
        'kwargs': {
          'context': {'inventory_mode': true, 'no_at_date': true},
        },
      });

      return true;
    } catch (e) {
      final raw = e.toString();

      final isValidation = raw.contains('odoo.exceptions.ValidationError');
      final mentionsSerial = raw.toLowerCase().contains('serial number');
      if (isValidation && mentionsSerial) {
        String? product;
        String? serial;
        final reg = RegExp(
          r'Product:\s*([^,\n]+),\s*Serial Number:\s*([^\n]+)',
        );
        final matches = reg.allMatches(raw).toList();
        for (final m in matches) {
          final p = m.group(1)?.trim();
          final s = m.group(2)?.trim();
          final looksHuman =
              (p != null && !p.contains('%(')) &&
              (s != null && !s.contains('%('));
          if (looksHuman) {
            product = p;
            serial = s;
            break;
          }
        }

        final userMsg = serial != null && product != null
            ? 'The serial number $serial for product "$product" is already assigned. Select a different lot/serial, undo the counted serial, or resolve the duplicate in Odoo.'
            : 'The serial number you entered is already assigned. Select a different lot/serial, undo the counted serial, or resolve the duplicate in Odoo.';

        throw ValidationException(
          'Serial number already assigned',
          userMsg,
          details: {
            if (product != null) 'product': product,
            if (serial != null) 'serial_number': serial,
            'quant_id': quantId,
          },
        );
      }

      throw OdooApiException(
        'Failed to apply adjustment',
        500,
        details: {'error': raw, 'quant_id': quantId},
      );
    }
  }

  Future<int?> createInventoryLine({
    required int productId,
    required int locationId,
    required double countedQuantity,
    DateTime? inventoryDate,
  }) async {
    try {
      final dateStr = inventoryDate != null
          ? "${inventoryDate.year}-${inventoryDate.month.toString().padLeft(2, '0')}-${inventoryDate.day.toString().padLeft(2, '0')}"
          : null;

      final payload = <String, dynamic>{
        'inventory_quantity_set': true,
        'location_id': locationId,
        'product_id': productId,
        'lot_id': false,
        'accounting_date': false,
        'inventory_quantity': countedQuantity,
      };
      if (dateStr != null) payload['inventory_date'] = dateStr;

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'web_save',
        'args': [[]],
        'kwargs': {
          'vals': payload,
          'specification': {
            'id': {},
            'inventory_quantity_set': {},
            'location_id': {
              'fields': {'display_name': {}},
            },
            'product_id': {
              'fields': {'display_name': {}},
            },
            'lot_id': {
              'fields': {'display_name': {}},
            },
            'accounting_date': {},
            'inventory_quantity': {},
            'inventory_date': {},
          },
          'context': {
            'inventory_mode': true,
            'no_at_date': true,
            'default_product_id': productId,
          },
        },
      });

      if (result is List && result.isNotEmpty) {
        final rec = result.first as Map<String, dynamic>;
        final id = rec['id'] as int?;
        return id;
      }
      return null;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('ValidationError') &&
          errorStr.contains(
            'Quants cannot be created for consumables or services',
          )) {
        throw ValidationException(
          'Invalid product type',
          'Inventory adjustments can only be created for storable products. This product is a consumable or service type and cannot have inventory counted.',
          details: {'product_id': productId, 'location_id': locationId},
        );
      }

      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLocations() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'search_read',
        'args': [
          [
            ['usage', '=', 'internal'],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'complete_name'],
          'limit': 100,
          'order': 'complete_name asc',
        },
      });

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }
}
