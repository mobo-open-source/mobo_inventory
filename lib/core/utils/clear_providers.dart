import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/inventory/providers/inventory_product_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/transfer/providers/transfer_provider.dart';
import '../../features/adjustment/providers/adjustment_provider.dart';
import '../../features/move_history/providers/move_history_provider.dart';
import '../../features/company/providers/company_provider.dart';
import '../../features/replenishment/providers/replenishment_provider.dart';

/// Resets all application providers to their initial state.
/// This is typically called during logout or account switching.
void resetAllAppProviders(BuildContext context) {
  try {
    context.read<InventoryProductProvider>().resetState();
    context.read<DashboardProvider>().resetState();

    context.read<ProfileProvider>().resetState();
    context.read<CompanyProvider>().initialize();

    context.read<TransferProvider>().clearFilters();
    context.read<AdjustmentProvider>().clearFilters();
    context.read<MoveHistoryProvider>().clearFilters();
    context.read<ReplenishmentProvider>().clearFilters();
  } catch (e) {}
}
