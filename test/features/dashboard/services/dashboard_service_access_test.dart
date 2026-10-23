import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/routing/app_routes.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/dashboard/providers/last_opened_provider.dart';
import 'package:mobo_inv_app/features/dashboard/services/dashboard_service.dart';

import '../helpers/fake_access.dart';

void main() {
  group('DashboardService without read access', () {
    final asked = <String>[];
    // Nothing is readable, so nothing may reach the server: these calls
    // would fail without a session if they tried.
    final service = DashboardService(
      canRead: (model) async {
        asked.add(model);
        return false;
      },
    );

    setUp(asked.clear);

    test('stats skip every count and hide every card', () async {
      final stats = await service.fetchDashboardStats();

      expect(stats.totalWarehouses, 0);
      expect(stats.deliveryOrders, 0);
      expect(stats.receipts, 0);
      expect(stats.internalTransfers, 0);
      expect(stats.manufacturingOrders, 0);
      expect(stats.negativeQuants, 0);
      expect(stats.showWarehouses, isFalse);
      expect(stats.showLocations, isFalse);
      expect(stats.showPickings, isFalse);
      expect(stats.showManufacturing, isFalse);
      expect(
        asked.toSet(),
        containsAll([
          'stock.warehouse',
          'stock.location',
          'stock.picking',
          'stock.quant',
          'mrp.production',
        ]),
      );
    });

    test('lists and today counts come back empty without a query', () async {
      expect(await service.fetchRecentActivities(), isEmpty);
      expect(await service.fetchNegativeQuants(), isEmpty);
      expect(await service.fetchReplenishmentNeeds(), isEmpty);
      expect(await service.fetchIncomingTodayCount(), 0);
      expect(await service.fetchOutgoingTodayCount(), 0);
      expect(asked.toSet(), {
        'stock.picking',
        'stock.quant',
        'stock.warehouse.orderpoint',
      });
    });
  });

  group('Recently opened items', () {
    LastOpenedItem item(String route) => LastOpenedItem(
      id: route,
      type: 'x',
      title: 'x',
      subtitle: 'x',
      route: route,
      lastAccessed: DateTime(2026),
      iconKey: 'page',
    );

    test('only those the user may open', () async {
      final access = noInventoryRightsAccess();
      await access.ensureLoaded();

      expect(item(AppRoutes.inventoryProductDetail).canOpen(access), isFalse);
      expect(item(AppRoutes.transferDetail).canOpen(access), isFalse);
      expect(item(AppRoutes.replenishment).canOpen(access), isFalse);
      expect(item(AppRoutes.warehouseList).canOpen(access), isTrue);
    });

    test('an Inventory User has no Replenish tab', () async {
      final access = fakeDashboardAccess(
        missingGroups: const {AccessRightsService.stockManagerGroup},
      );
      await access.ensureLoaded();

      expect(item(AppRoutes.inventoryProductDetail).canOpen(access), isTrue);
      expect(item(AppRoutes.transferDetail).canOpen(access), isTrue);
      expect(item(AppRoutes.replenishment).canOpen(access), isFalse);
    });
  });
}
