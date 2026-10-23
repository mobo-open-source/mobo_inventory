import '../../../core/odoo/odoo_user_groups.dart';
import '../../../core/services/access_rights_service.dart';
import '../../../core/services/odoo_metadata_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../manufacturing/services/manufacturing_service.dart';
import '../../picking/services/picking_service.dart';
import '../../replenishment/services/replenishment_service.dart';
import '../models/dashboard_stats.dart';
import '../models/recent_activity.dart';
import '../models/negative_quant.dart';
import '../models/today_activity.dart';
import '../models/replenishment_need.dart';

/// Service for fetching dashboard-related data from Odoo using RPC calls.
///
/// Every count runs through [OdooSessionManager.callKwWithCompany], so it
/// covers the selected and allowed companies — the same scope as the list
/// each card opens.
///
/// A query on a model the user may not read is skipped rather than sent:
/// the Dashboard is the one tab every user has, including those without
/// Inventory rights, and an access error there would replace the whole
/// overview with an error screen.
class DashboardService {
  DashboardService({Future<bool> Function(String model)? canRead})
    : _canRead =
          canRead ??
          ((model) => AccessRightsService.instance.check(model, 'read'));

  /// Whether the user may read a model — Odoo's answer, failing open when
  /// it can't be had (the query then surfaces its own error, as before).
  final Future<bool> Function(String model) _canRead;

  /// Quants in a virtual location (vendors, customers, inventory
  /// adjustment, production, scrap) go negative by design; only stock held
  /// in a warehouse can really be short. Odoo's own stock views use the
  /// same scope.
  static const List<dynamic> _storedStockDomain = [
    'location_id.usage',
    'in',
    ['internal', 'transit'],
  ];

  /// Fetches warehouse, location, and picking counts for the dashboard.
  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final readable = await Future.wait([
        _canRead('stock.warehouse'),
        _canRead('stock.location'),
        _canRead('stock.picking'),
        _canRead('stock.quant'),
      ]);
      final canReadWarehouses = readable[0];
      final canReadLocations = readable[1];
      final canReadPickings = readable[2];
      final canReadQuants = readable[3];

      // Inventory > Settings > Storage Locations. Unknown (the check itself
      // failed) keeps the tile, as before.
      final showLocations =
          canReadLocations &&
          (await OdooUserGroups.settingEnabled(OdooUserGroups.multiLocations) ??
              true);

      Future<int> none() => Future<int>.value(0);

      // Point of Sale's operation types: Odoo's Inventory Overview counts
      // their pickings on a PoS Orders card, not under Delivery Orders.
      final posTypeIds = canReadPickings
          ? await PickingService.posPickingTypeIds()
          : const <int>[];

      final results = await Future.wait<Object?>([
        // Odoo's Warehouses list: the active warehouses of the allowed
        // companies (its record rule), which is what an empty domain
        // searches in the company context.
        canReadWarehouses ? _count('stock.warehouse', const []) : none(),
        showLocations
            ? _count('stock.location', const [
                ['usage', '=', 'internal'],
              ])
            : none(),
        // Receipts, Delivery Orders and Internal Transfers show Odoo's
        // "To Process": the domain the card's list opens with.
        canReadPickings
            ? _toProcessCount('outgoing', excludedPickingTypeIds: posTypeIds)
            : none(),
        canReadPickings ? _toProcessCount('incoming') : none(),
        canReadPickings ? _toProcessCount('internal') : none(),
        canReadQuants
            ? _count('stock.quant', const [
                ['quantity', '<', 0],
                _storedStockDomain,
              ])
            : none(),
        _fetchManufacturingCounts(),
        posTypeIds.isNotEmpty
            ? _toProcessCount('outgoing', pickingTypeIds: posTypeIds)
            : none(),
      ]);

      final readyToDeliver = results[2] as int;
      final readyToReceive = results[3] as int;
      final readyToTransfer = results[4] as int;
      final manufacturing = results[6] as ({int toDo, int ready})?;

      return DashboardStats(
        totalWarehouses: results[0] as int,
        totalLocations: results[1] as int,
        deliveryOrders: readyToDeliver,
        readyToDeliver: readyToDeliver,
        receipts: readyToReceive,
        readyToReceive: readyToReceive,
        internalTransfers: readyToTransfer,
        readyToTransfer: readyToTransfer,
        manufacturingOrders: manufacturing?.toDo ?? 0,
        readyToProduce: manufacturing?.ready ?? 0,
        negativeQuants: results[5] as int,
        posOrders: results[7] as int,
        showWarehouses: canReadWarehouses,
        showLocations: showLocations,
        showPickings: canReadPickings,
        showManufacturing: manufacturing != null,
        showPosOrders: posTypeIds.isNotEmpty,
      );
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  /// Pickings of [pickingTypeCode] that Odoo's Inventory Overview counts as
  /// "To Process" (`count_picking_ready`, summed over the operation types).
  /// Built with the exact domain of the list the card opens, so the card's
  /// number is that list's total. [pickingTypeIds] and
  /// [excludedPickingTypeIds] split the PoS operation types from the rest.
  Future<int> _toProcessCount(
    String pickingTypeCode, {
    List<int>? pickingTypeIds,
    List<int> excludedPickingTypeIds = const [],
  }) => _count(
    'stock.picking',
    PickingService.buildDomain(
      pickingTypeCode: pickingTypeCode,
      states: PickingService.toProcessStates,
      pickingTypeIds: pickingTypeIds,
      excludedPickingTypeIds: excludedPickingTypeIds,
    ),
  );

  /// The "To Do" manufacturing orders (what the card's list opens with) and
  /// those of them that are ready — Odoo's "MO Ready" filter: every
  /// component reserved.
  ///
  /// Null when the dashboard shouldn't show manufacturing at all: the user
  /// may not read manufacturing orders, the `mrp` module isn't installed (so
  /// Odoo has no `mrp.production` model), or the orders can't be read.
  /// Never throws, so manufacturing can't take the rest of the dashboard
  /// down with it.
  Future<({int toDo, int ready})?> _fetchManufacturingCounts() async {
    try {
      if (!await _canRead('mrp.production')) return null;
      if (!await OdooMetadataService.hasModel('mrp.production')) return null;

      final toDoDomain = ManufacturingService.buildDomain(
        states: ManufacturingService.toDoStates,
      );
      final counts = await Future.wait([
        _count('mrp.production', toDoDomain),
        _count('mrp.production', [
          ...toDoDomain,
          ['reservation_state', '=', 'assigned'],
        ]),
      ]);
      return (toDo: counts[0], ready: counts[1]);
    } catch (_) {
      return null;
    }
  }

  Future<int> _count(String model, List<dynamic> domain) async {
    final res = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'search_count',
      'args': [domain],
      'kwargs': {},
    });
    return res as int;
  }

  Future<List<RecentActivity>> fetchRecentActivities({int limit = 10}) async {
    try {
      if (!await _canRead('stock.picking')) return [];
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
      if (!await _canRead('stock.quant')) return [];
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.quant',
        'method': 'search_read',
        'args': [
          [
            ['quantity', '<', 0],
            _storedStockDomain,
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
      return await _todayCount('incoming');
    } catch (e) {
      throw Exception('Failed to fetch incoming today count: $e');
    }
  }

  Future<int> fetchOutgoingTodayCount() async {
    try {
      return await _todayCount('outgoing');
    } catch (e) {
      throw Exception('Failed to fetch outgoing today count: $e');
    }
  }

  /// Open (not draft, done or cancelled) pickings of [pickingTypeCode]
  /// scheduled on the user's current local day.
  Future<int> _todayCount(String pickingTypeCode) async {
    if (!await _canRead('stock.picking')) return 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    final res = await OdooSessionManager.callKwWithCompany({
      'model': 'stock.picking',
      'method': 'search_count',
      'args': [
        [
          ['picking_type_code', '=', pickingTypeCode],
          [
            'state',
            'in',
            ['waiting', 'confirmed', 'assigned'],
          ],
          ['scheduled_date', '>=', _odooUtc(start)],
          ['scheduled_date', '<', _odooUtc(end)],
        ],
      ],
      'kwargs': {},
    });
    return res as int;
  }

  /// Odoo stores datetimes in UTC as `YYYY-MM-DD HH:MM:SS`, so a local
  /// day boundary has to be converted before it is compared with them.
  static String _odooUtc(DateTime local) {
    final u = local.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)} '
        '${two(u.hour)}:${two(u.minute)}:${two(u.second)}';
  }

  /// The orderpoints Odoo's Replenishment screen lists by default ("To
  /// Reorder", "Not Snoozed", either trigger), most to order first.
  ///
  /// Quantities come from the orderpoint itself, which Odoo computes for the
  /// orderpoint's own location and from the *forecast* — not from the
  /// product's company-wide on-hand stock, which flagged products whose
  /// shortfall is already covered by incoming receipts.
  Future<List<ReplenishmentNeed>> fetchReplenishmentNeeds({
    int limit = 4,
  }) async {
    try {
      if (!await _canRead('stock.warehouse.orderpoint')) return [];
      final orderpoints = await OdooSessionManager.callKwWithCompany({
        'model': 'stock.warehouse.orderpoint',
        'method': 'search_read',
        'args': [
          ReplenishmentService().buildDomain(toReorder: true, trigger: ''),
        ],
        'kwargs': {
          'fields': [
            'id',
            'product_id',
            'location_id',
            'product_min_qty',
            'product_max_qty',
            'qty_on_hand',
            'qty_forecast',
            'qty_to_order',
          ],
          // `qty_to_order` is not stored on every release, so it cannot be
          // the server-side order; the largest are picked out below.
          'limit': 200,
        },
      });

      if (orderpoints is! List) return [];

      final needs = orderpoints
          .whereType<Map<String, dynamic>>()
          .map(ReplenishmentNeed.fromOrderpoint)
          .whereType<ReplenishmentNeed>()
          .where((n) => n.toOrder > 0)
          .toList();

      needs.sort((a, b) => b.toOrder.compareTo(a.toOrder));
      return needs.length > limit ? needs.sublist(0, limit) : needs;
    } catch (e) {
      throw Exception('Failed to fetch replenishment needs: $e');
    }
  }
}
