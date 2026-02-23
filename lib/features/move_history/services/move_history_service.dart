
import 'package:flutter/foundation.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../models/move_history_item.dart';

class MoveHistoryService {

  Future<List<MoveHistoryItem>> fetchHistory({
    int offset = 0,
    int limit = 20,
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool activeOnly = false,
    bool inventoryOnly = false,
  }) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();

      final List<dynamic> domain = [];

      if (activeOnly) {
        domain.add(['move_id.state', 'not in', ['done', 'draft', 'cancel']]);
      } else if (status != null && status.isNotEmpty) {
        domain.add(['move_id.state', '=', status]);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {

        domain.add(['|', ['product_id', 'ilike', searchQuery], ['move_id.name', 'ilike', searchQuery]]);
      }

      if (pickingTypeCodes != null && pickingTypeCodes.isNotEmpty) {
        List<dynamic> ors = [];
        for (final code in pickingTypeCodes) {
          ors.add(['picking_id.picking_type_id.code', '=', code]);
        }
        if (ors.length == 1) {
          domain.add(ors.first);
        } else {

          dynamic combined = ors.last;
          for (int i = ors.length - 2; i >= 0; i--) {
            combined = ['|', ors[i], combined];
          }
          domain.add(combined);
        }
      }

      String fmt(DateTime d) {

        final dt = d.toUtc();
        String two(int v) => v.toString().padLeft(2, '0');
        return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
      }

      if (dateFrom != null) {
        domain.add(['date', '>=', fmt(dateFrom)]);
      }
      if (dateTo != null) {
        domain.add(['date', '<=', fmt(dateTo)]);
      }

      if (inventoryOnly) {
        domain.add(['move_id.is_inventory', '=', true]);
      }

      dynamic result;
      try {
        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_read',
          'args': [domain],
          'kwargs': {
            'fields': [
              'id',
              'date',
              'state',
              'quantity',
              'product_id',
              'lot_id',
              'location_id',
              'location_dest_id',
              'move_id',
              'picking_id',
            ],
            'offset': offset,
            'limit': limit,
            'order': 'date desc, id desc',
            'context': {
              'lang': 'en_US',
              'tz': 'Asia/Calcutta',
            },
          },
        });
      } catch (e) {
        
        final List<dynamic> simpleDomain = [];
        if (activeOnly) {
          simpleDomain.add(['state', 'not in', ['done', 'draft', 'cancel']]);
        } else if (status != null && status.isNotEmpty) {
          simpleDomain.add(['state', '=', status]);
        }
        if (searchQuery != null && searchQuery.isNotEmpty) {
          simpleDomain.add(['product_id', 'ilike', searchQuery]);
        }

        if (inventoryOnly) simpleDomain.add(['move_id.is_inventory', '=', true]);

        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_read',
          'args': [simpleDomain],
          'kwargs': {
            'fields': [
              'id', 'date', 'state', 'quantity', 'product_id', 'lot_id', 'location_id', 'location_dest_id', 'move_id'
            ],
            'offset': offset,
            'limit': limit,
            'order': 'date desc, id desc',
            'context': {
              'lang': 'en_US',
              'tz': 'Asia/Calcutta',
            },
          },
        });
      }

      if (result is List) {
        var items = result
            .cast<Map<String, dynamic>>()
            .map((e) => MoveHistoryItem.fromJson(e))
            .toList();

        final locIds = <int>{};
        for (final it in items) {
          if (it.fromLocationId != null) locIds.add(it.fromLocationId!);
          if (it.toLocationId != null) locIds.add(it.toLocationId!);
        }
        Map<int, String> usageById = {};
        if (locIds.isNotEmpty) {
          try {
            final locs = await OdooSessionManager.callKwWithCompany({
              'model': 'stock.location',
              'method': 'search_read',
              'args': [
                [
                  ['id', 'in', locIds.toList()]
                ]
              ],
              'kwargs': {
                'fields': ['id', 'usage'],
                'limit': locIds.length,
              },
            });
            if (locs is List) {
              for (final m in locs.cast<Map<String, dynamic>>()) {
                final id = m['id'] as int?;
                final usage = m['usage']?.toString();
                if (id != null && usage != null) usageById[id] = usage;
              }
            }
          } catch (e) {
                      }
        }

        bool isInternal(String? u) => u == 'internal' || u == 'transit';
        items = items
            .map((it) {
              final fromUsage = usageById[it.fromLocationId ?? -1];
              final toUsage = usageById[it.toLocationId ?? -1];
              int sign = 0;
              if (isInternal(toUsage)) sign += 1;
              if (isInternal(fromUsage)) sign -= 1;
              final signedQty = sign == 0 ? it.quantity : (it.quantity * sign);
              return it.copyWith(quantity: signedQty);
            })
            .toList();

        final productIds = <int>{};
        for (final it in items) {
          if (it.productId != null) productIds.add(it.productId!);
        }
        if (productIds.isNotEmpty) {
          try {
            final prods = await OdooSessionManager.callKwWithCompany({
              'model': 'product.product',
              'method': 'search_read',
              'args': [
                [
                  ['id', 'in', productIds.toList()]
                ]
              ],
              'kwargs': {
                'fields': ['id', 'categ_id'],
                'limit': productIds.length,
              },
            });
            final catByProd = <int, String>{};
            if (prods is List) {
              for (final m in prods.cast<Map<String, dynamic>>()) {
                final pid = m['id'] as int?;
                final c = m['categ_id'];
                String? cname;
                if (c is List && c.isNotEmpty) {
                  cname = c.length > 1 ? c[1].toString() : null;
                } else if (c is Map<String, dynamic>) {
                  cname = c['display_name']?.toString();
                }
                if (pid != null && cname != null) catByProd[pid] = cname;
              }
            }
            if (catByProd.isNotEmpty) {
              items = items
                  .map((it) => it.productId != null && catByProd.containsKey(it.productId!)
                      ? it.copyWith(productCategory: catByProd[it.productId!])
                      : it)
                  .toList();
            }
          } catch (e) {
                      }
        }

                return items;
      }
      return [];
    } catch (e) {
            rethrow;
    }
  }

  Future<int> getHistoryCount({
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool activeOnly = false,
    bool inventoryOnly = false,
  }) async {
    try {
      final client = await OdooSessionManager.getClientEnsured();

      final List<dynamic> domain = [];
      if (activeOnly) {
        domain.add(['move_id.state', 'not in', ['done', 'draft', 'cancel']]);
      } else if (status != null && status.isNotEmpty) {
        domain.add(['move_id.state', '=', status]);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add(['|', ['product_id', 'ilike', searchQuery], ['move_id.name', 'ilike', searchQuery]]);
      }

      if (pickingTypeCodes != null && pickingTypeCodes.isNotEmpty) {
        List<dynamic> ors = [];
        for (final code in pickingTypeCodes) {
          ors.add(['picking_id.picking_type_id.code', '=', code]);
        }
        if (ors.length == 1) {
          domain.add(ors.first);
        } else {
          dynamic combined = ors.last;
          for (int i = ors.length - 2; i >= 0; i--) {
            combined = ['|', ors[i], combined];
          }
          domain.add(combined);
        }
      }
      String fmt(DateTime d) {
        final dt = d.toUtc();
        String two(int v) => v.toString().padLeft(2, '0');
        return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
      }
      if (dateFrom != null) {
        domain.add(['date', '>=', fmt(dateFrom)]);
      }
      if (dateTo != null) {
        domain.add(['date', '<=', fmt(dateTo)]);
      }

      dynamic result;
      try {
        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_count',
          'args': [domain],
          'kwargs': {
            'context': {
              'lang': 'en_US',
              'tz': 'Asia/Calcutta',
            }
          }
        });
      } catch (e) {
                final List<dynamic> simpleDomain = [];
        if (activeOnly) {
          simpleDomain.add(['state', 'not in', ['done', 'draft', 'cancel']]);
        } else if (status != null && status.isNotEmpty) {

          simpleDomain.add(['state', '=', status]);
        }
        if (searchQuery != null && searchQuery.isNotEmpty) {
          simpleDomain.add(['product_id', 'ilike', searchQuery]);
        }

        if (inventoryOnly) simpleDomain.add(['move_id.is_inventory', '=', true]);

        result = await OdooSessionManager.callKwWithCompany({
          'model': 'stock.move.line',
          'method': 'search_count',
          'args': [simpleDomain],
          'kwargs': {
            'context': {
              'lang': 'en_US',
              'tz': 'Asia/Calcutta',
            }
          }
        });
      }

      return result is int ? result : 0;
    } catch (e) {
            return 0;
    }
  }

}
