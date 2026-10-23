import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_inv_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:mobo_inv_app/features/dashboard/services/dashboard_service.dart';
import 'package:mobo_inv_app/features/dashboard/models/dashboard_stats.dart';
import 'package:mobo_inv_app/features/dashboard/models/recent_activity.dart';
import 'package:mobo_inv_app/features/dashboard/models/negative_quant.dart';
import 'package:mobo_inv_app/features/dashboard/models/today_activity.dart';
import 'package:mobo_inv_app/features/dashboard/models/replenishment_need.dart';

class MockDashboardService extends Mock implements DashboardService {}

void main() {
  late DashboardProvider provider;
  late MockDashboardService mockService;

  setUp(() {
    mockService = MockDashboardService();
    provider = DashboardProvider(service: mockService);
  });

  group('DashboardProvider Tests', () {
    test('fetchStats success', () async {
      final stats = DashboardStats(
        totalWarehouses: 1,
        totalLocations: 10,
        deliveryOrders: 5,
        readyToDeliver: 2,
        receipts: 3,
        readyToReceive: 1,
        internalTransfers: 4,
        readyToTransfer: 0,
        manufacturingOrders: 0,
        readyToProduce: 0,
        negativeQuants: 0,
      );

      when(
        () => mockService.fetchDashboardStats(),
      ).thenAnswer((_) async => stats);

      await provider.fetchStats();

      expect(provider.isLoading, false);
      expect(provider.stats, stats);
      expect(provider.hasLoadedData, true);
      expect(provider.error, null);
    });

    test('fetchStats failure', () async {
      when(
        () => mockService.fetchDashboardStats(),
      ).thenThrow(Exception('Failed'));

      await provider.fetchStats();

      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      // Note: stats are NOT reset on general exception, only on connection error (as per code logic)
      // If we want to test empty stats on connection error, we'd need to mock connection exception
    });

    test('fetchRecentActivities success', () async {
      final activities = <RecentActivity>[
        RecentActivity(
          id: 1,
          name: 'WH/OUT/001',
          type: 'outgoing',
          model: 'stock.picking',
          state: 'done',
          date: DateTime.now(),
        ),
      ];
      when(
        () => mockService.fetchRecentActivities(limit: any(named: 'limit')),
      ).thenAnswer((_) async => activities);

      await provider.fetchRecentActivities();

      expect(provider.isLoadingRecent, false);
      expect(provider.recentActivities, activities);
    });

    test('fetchRecentActivities failure', () async {
      when(
        () => mockService.fetchRecentActivities(limit: any(named: 'limit')),
      ).thenThrow(Exception('Error'));

      await provider.fetchRecentActivities();

      expect(provider.isLoadingRecent, false);
      expect(provider.recentActivities, isEmpty);
    });

    test('fetchNegativeQuants success', () async {
      final quants = <NegativeQuant>[
        NegativeQuant(
          id: 1,
          quantity: -10,
          productName: 'P1',
          locationName: 'Stock',
        ),
      ];
      when(
        () => mockService.fetchNegativeQuants(limit: any(named: 'limit')),
      ).thenAnswer((_) async => quants);

      await provider.fetchNegativeQuants();

      expect(provider.isLoadingNegative, false);
      expect(provider.negativeQuants, quants);
    });

    test('fetchTodayActivities success', () async {
      final todayActs = [
        TodayActivity(
          id: 1,
          resModel: 'stock.picking',
          resId: 100,
          summary: 'Call client',
          deadline: DateTime.now(),
        ),
      ];
      when(
        () => mockService.fetchTodayActivities(limit: any(named: 'limit')),
      ).thenAnswer((_) async => todayActs);

      await provider.fetchTodayActivities();

      expect(provider.isLoadingToday, false);
      expect(provider.todayActivities, todayActs);
    });

    test('fetchReplenishmentNeeds success', () async {
      final needs = [
        ReplenishmentNeed(
          productId: 1,
          productName: 'Prod',
          minQty: 10,
          maxQty: 20,
          onHand: 5,
          forecast: 5,
          toOrder: 15,
        ),
      ];
      when(
        () => mockService.fetchReplenishmentNeeds(limit: any(named: 'limit')),
      ).thenAnswer((_) async => needs);

      await provider.fetchReplenishmentNeeds();

      expect(provider.isLoadingReplenishment, false);
      expect(provider.replenishmentNeeds, needs);
    });

    test('a forced reload supersedes a load still running', () async {
      DashboardStats statsWith(int warehouses) => DashboardStats(
        totalWarehouses: warehouses,
        totalLocations: 0,
        deliveryOrders: 0,
        readyToDeliver: 0,
        receipts: 0,
        readyToReceive: 0,
        internalTransfers: 0,
        readyToTransfer: 0,
        manufacturingOrders: 0,
        readyToProduce: 0,
        negativeQuants: 0,
      );
      // The first load went out under the old company scope and answers
      // last; the reload for the new scope must win.
      final oldScope = Completer<DashboardStats>();
      final newScope = Completer<DashboardStats>();
      final answers = [oldScope, newScope];
      when(
        () => mockService.fetchDashboardStats(),
      ).thenAnswer((_) => answers.removeAt(0).future);

      final first = provider.fetchStats();
      // A plain call while loading is still ignored.
      await provider.fetchStats();
      expect(answers, hasLength(1));

      final reload = provider.fetchStats(forceRefresh: true);
      newScope.complete(statsWith(1));
      await reload;
      expect(provider.stats.totalWarehouses, 1);
      expect(provider.isLoading, false);

      oldScope.complete(statsWith(3));
      await first;
      expect(provider.stats.totalWarehouses, 1);
      expect(provider.isLoading, false);
    });

    test('resetState drops a load started for the previous account', () async {
      final pending = Completer<List<RecentActivity>>();
      when(
        () => mockService.fetchRecentActivities(limit: any(named: 'limit')),
      ).thenAnswer((_) => pending.future);

      final load = provider.fetchRecentActivities();
      expect(provider.isLoadingRecent, true);
      provider.resetState();
      expect(provider.isLoadingRecent, false);

      pending.complete([
        RecentActivity(
          id: 1,
          name: 'WH/OUT/001',
          type: 'outgoing',
          model: 'stock.picking',
          state: 'done',
          date: DateTime.now(),
        ),
      ]);
      await load;
      expect(provider.recentActivities, isEmpty);
    });

    test('showManufacturing defaults to shown', () {
      expect(DashboardStats.empty().showManufacturing, true);
    });

    test('resetState clears all data', () {
      provider.resetState();
      expect(provider.stats.totalWarehouses, 0);
      expect(provider.recentActivities, isEmpty);
      expect(provider.negativeQuants, isEmpty);
    });
  });
}
