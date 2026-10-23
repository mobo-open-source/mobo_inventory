import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/inventory/providers/inventory_product_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../../features/dashboard/providers/last_opened_provider.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/transfer/providers/transfer_provider.dart';
import '../../features/adjustment/providers/adjustment_provider.dart';
import '../../features/move_history/providers/move_history_provider.dart';
import '../../features/company/data/company_local_datasource.dart';
import '../../features/company/providers/company_provider.dart';
import '../../features/replenishment/providers/replenishment_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../services/odoo_metadata_service.dart';

/// Drops everything loaded for the outgoing account, so every screen fetches
/// again for the account now signed in (or shows nothing when signed out).
///
/// Runs automatically on every account change — see `AccountChangeListener`
/// — so login, logout, switch, add-account and the forced sign-outs all go
/// through the same reset. Covers:
///
/// * every app-wide list provider — their *data*, not only their filters;
/// * the companies, including the offline Isar copy and a pending company
///   switch, which would otherwise offer the old account's companies;
/// * the recent items and the Settings screen's per-server lists;
/// * the "is this module installed?" cache, answered for the old server.
///
/// Providers scoped to a single route (warehouses, locations, pickings,
/// manufacturing) are not listed: they are recreated whenever their screen
/// is opened.
Future<void> resetAllAppProviders(BuildContext context) async {
  // Read up front: the awaits below may outlive this context.
  InventoryProductProvider? inventory;
  DashboardProvider? dashboard;
  ProfileProvider? profile;
  TransferProvider? transfer;
  AdjustmentProvider? adjustment;
  MoveHistoryProvider? moveHistory;
  ReplenishmentProvider? replenishment;
  CompanyProvider? company;
  SettingsProvider? settings;
  LastOpenedProvider? lastOpened;
  try {
    inventory = context.read<InventoryProductProvider>();
    dashboard = context.read<DashboardProvider>();
    profile = context.read<ProfileProvider>();
    transfer = context.read<TransferProvider>();
    adjustment = context.read<AdjustmentProvider>();
    moveHistory = context.read<MoveHistoryProvider>();
    replenishment = context.read<ReplenishmentProvider>();
    company = context.read<CompanyProvider>();
    settings = context.read<SettingsProvider>();
    lastOpened = context.read<LastOpenedProvider>();
  } catch (_) {
    // Called from a context without the app's providers above it.
    return;
  }

  OdooMetadataService.reset();

  inventory.resetState();
  dashboard.resetState();
  profile.resetState();
  transfer.resetState();
  adjustment.resetState();
  moveHistory.resetState();
  replenishment.resetState();
  company.reset();

  // The offline copy is cleared before companies are fetched again, so the
  // fetch's own write for the new account cannot be wiped by it.
  try {
    await CompanyLocalDataSource().clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_company_id');
  } catch (_) {}
  await company.initialize();

  await settings.resetServerData();
  await lastOpened.reloadForCurrentAccount();
}
