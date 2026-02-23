import '../../../core/services/odoo_session_manager.dart';
import '../models/dashboard_stats.dart';
import '../models/recent_activity.dart';
import '../models/negative_quant.dart';
import '../models/today_activity.dart';
import '../models/replenishment_need.dart';

/// Service for fetching dashboard-related data from Odoo using RPC calls.
class DashboardService {
  /// Fetches warehouse, location, and picking counts for the dashboard.
  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final warehouseCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse',
        'method': 'search_count',
        'args': [[]],
        'kwargs': {},
      });

      final locationCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.location',
        'method': 'search_count',
        'args': [
          [
            ['usage', '=', 'internal'],
          ],
        ],
        'kwargs': {},
      });

      final deliveryCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'outgoing'],
            [
              'state',
              'not in',
              ['done', 'cancel'],
            ],
          ],
        ],
        'kwargs': {},
      });

      final readyToDeliverCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'outgoing'],
            ['state', '=', 'assigned'],
          ],
        ],
        'kwargs': {},
      });

      final receiptCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'incoming'],
            [
              'state',
              'not in',
              ['done', 'cancel'],
            ],
          ],
        ],
        'kwargs': {},
      });

      final readyToReceiveCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'incoming'],
            ['state', '=', 'assigned'],
          ],
        ],
        'kwargs': {},
      });

      final transferCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'internal'],
            [
              'state',
              'not in',
              ['done', 'cancel'],
            ],
          ],
        ],
        'kwargs': {},
      });

      final readyToTransferCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'internal'],
            ['state', '=', 'assigned'],
          ],
        ],
        'kwargs': {},
      });

      int manufacturingCount = 0;
      int readyToProduceCount = 0;
      try {
        manufacturingCount =
            await OdooSessionManager.callKwWithCompany({
                  'model': 'mrp.production',
                  'method': 'search_count',
                  'args': [
                    [
                      [
                        'state',
                        'not in',
                        ['done', 'cancel'],
                      ],
                    ],
                  ],
                  'kwargs': {},
                })
                as int;

        readyToProduceCount =
            await OdooSessionManager.callKwWithCompany({
                  'model': 'mrp.production',
                  'method': 'search_count',
                  'args': [
                    [
                      ['state', '=', 'confirmed'],
                    ],
                  ],
                  'kwargs': {},
                })
                as int;
      } catch (e) {
        manufacturingCount = 0;
        readyToProduceCount = 0;
      }

      final negativeQuantsCount = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'search_count',
        'args': [
          [
            ['quantity', '<', 0],
          ],
        ],
        'kwargs': {},
      });

      return DashboardStats(
        totalWarehouses: warehouseCount as int,
        totalLocations: locationCount as int,
        deliveryOrders: deliveryCount as int,
        readyToDeliver: readyToDeliverCount as int,
        receipts: receiptCount as int,
        readyToReceive: readyToReceiveCount as int,
        internalTransfers: transferCount as int,
        readyToTransfer: readyToTransferCount as int,
        manufacturingOrders: manufacturingCount,
        readyToProduce: readyToProduceCount,
        negativeQuants: (negativeQuantsCount as int),
      );
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  Future<List<RecentActivity>> fetchRecentActivities({int limit = 10}) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [
          [
            [
              'state',
              'not in',
              ['cancel'],
            ],
          ],
        ],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'picking_type_code',
            'state',
            'scheduled_date',
            'write_date',
          ],
          'order': 'write_date desc',
          'limit': limit,
        },
      });

      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((e) => RecentActivity.fromPicking(e))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch recent activities: $e');
    }
  }

  Future<List<NegativeQuant>> fetchNegativeQuants({int limit = 4}) async {
    try {
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'search_read',
        'args': [
          [
            ['quantity', '<', 0],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'product_id', 'location_id', 'quantity'],
          'order': 'quantity asc',
          'limit': limit,
        },
      });

      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((e) => NegativeQuant.fromMap(e))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch negative quants: $e');
    }
  }

  Future<List<TodayActivity>> fetchTodayActivities({int limit = 4}) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final uid = session?.userId;
      if (uid == null) return [];

      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);
      final domain = [
        ['user_id', '=', uid],
        [
          'res_model',
          'in',
          ['stock.picking', 'stock.move', 'stock.quant', 'mrp.production'],
        ],
        ['date_deadline', '<=', todayStr],
      ];

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'mail.activity',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [
            'id',
            'res_model',
            'res_id',
            'summary',
            'note',
            'date_deadline',
          ],
          'order': 'date_deadline asc, id desc',
          'limit': limit,
        },
      });

      if (res is List) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((e) => TodayActivity.fromMap(e))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch today\'s activities: $e');
    }
  }

  Future<int> fetchIncomingTodayCount() async {
    try {
      final today = DateTime.now();
      final start = DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String();
      final end = DateTime(
        today.year,
        today.month,
        today.day,
        23,
        59,
        59,
      ).toIso8601String();
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'incoming'],
            [
              'state',
              'not in',
              ['done', 'cancel'],
            ],
            ['scheduled_date', '>=', start],
            ['scheduled_date', '<=', end],
          ],
        ],
        'kwargs': {},
      });
      return (res as int);
    } catch (e) {
      throw Exception('Failed to fetch incoming today count: $e');
    }
  }

  Future<int> fetchOutgoingTodayCount() async {
    try {
      final today = DateTime.now();
      final start = DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String();
      final end = DateTime(
        today.year,
        today.month,
        today.day,
        23,
        59,
        59,
      ).toIso8601String();
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.picking',
        'method': 'search_count',
        'args': [
          [
            ['picking_type_code', '=', 'outgoing'],
            [
              'state',
              'not in',
              ['done', 'cancel'],
            ],
            ['scheduled_date', '>=', start],
            ['scheduled_date', '<=', end],
          ],
        ],
        'kwargs': {},
      });
      return (res as int);
    } catch (e) {
      throw Exception('Failed to fetch outgoing today count: $e');
    }
  }

  Future<List<ReplenishmentNeed>> fetchReplenishmentNeeds({
    int limit = 4,
  }) async {
    try {
      final orderpoints = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'product_id', 'product_min_qty', 'product_max_qty'],
          'limit': 50,
        },
      });

      if (orderpoints is! List) return [];

      final productIds = <int>{};
      final opList = <Map<String, dynamic>>[];
      for (final item in orderpoints.whereType<Map<String, dynamic>>()) {
        final rel = item['product_id'];
        if (rel is List && rel.isNotEmpty) {
          productIds.add((rel.first as num).toInt());
        }
        opList.add(item);
      }
      if (productIds.isEmpty) return [];

      final products = await OdooSessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'read',
        'args': [
          productIds.toList(),
          ['qty_available', 'display_name'],
        ],
        'kwargs': {},
      });

      final qtyById = <int, Map<String, dynamic>>{};
      if (products is List) {
        for (final p in products.whereType<Map<String, dynamic>>()) {
          final id = (p['id'] as num).toInt();
          qtyById[id] = p;
        }
      }

      final needs = <ReplenishmentNeed>[];
      for (final item in opList) {
        final rel = item['product_id'];
        if (rel is List && rel.length >= 2) {
          final pid = (rel.first as num).toInt();
          final pname = rel[1].toString();
          final minQty = ((item['product_min_qty'] ?? 0) as num).toDouble();
          final maxQty = ((item['product_max_qty'] ?? 0) as num).toDouble();
          final product = qtyById[pid];
          final onHand = product != null
              ? ((product['qty_available'] ?? 0) as num).toDouble()
              : 0.0;
          if (onHand < minQty) {
            needs.add(
              ReplenishmentNeed(
                productId: pid,
                productName: pname.isNotEmpty
                    ? pname
                    : (product?['display_name']?.toString() ?? '—'),
                minQty: minQty,
                maxQty: maxQty,
                onHand: onHand,
              ),
            );
          }
        }
      }

      needs.sort((a, b) => (b.shortage).compareTo(a.shortage));
      if (needs.length > limit) {
        return needs.sublist(0, limit);
      }
      return needs;
    } catch (e) {
      throw Exception('Failed to fetch replenishment needs: $e');
    }
  }
}
