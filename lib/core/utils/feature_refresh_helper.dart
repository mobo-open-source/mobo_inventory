import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/inventory/providers/inventory_product_provider.dart';
import '../../features/transfer/providers/transfer_provider.dart';
import '../../features/manufacturing/providers/manufacturing_provider.dart';
import '../../features/picking/providers/picking_provider.dart';
import '../../features/move_history/providers/move_history_provider.dart';
import '../../features/locations/providers/location_provider.dart';
import '../../features/warehouse/providers/warehouse_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../../features/replenishment/providers/replenishment_provider.dart';

class FeatureRefreshHelper {
  static Future<void> refreshAll(BuildContext context) async {
    Future<void> safeCall<T>(Future<void> Function(T p) fn) async {
      try {
        if (!context.mounted) return;
        final p = context.read<T>();
        await fn(p);
      } catch (_) {}
    }

    await Future.wait([
      safeCall<InventoryProductProvider>(
        (p) => p.fetchProducts(forceRefresh: true),
      ),
      safeCall<TransferProvider>(
        (p) => p.fetchTransfers(forceRefresh: true, updateFilters: false),
      ),
      safeCall<ManufacturingProvider>(
        (p) => p.fetchProductions(forceRefresh: true),
      ),
      safeCall<MoveHistoryProvider>((p) => p.refresh()),
      safeCall<LocationProvider>((p) => p.fetchLocations(forceRefresh: true)),
      safeCall<WarehouseProvider>((p) => p.fetchWarehouses(forceRefresh: true)),
      safeCall<PickingProvider>((p) => p.fetchPickings(forceRefresh: true)),
      safeCall<DashboardProvider>((p) => p.refreshAll()),
      safeCall<ReplenishmentProvider>((p) => p.fetch(forceRefresh: true)),
    ]);
  }
}
