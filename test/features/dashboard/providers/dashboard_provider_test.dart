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
        ),
      ];
      when(
        () => mockService.fetchReplenishmentNeeds(limit: any(named: 'limit')),
      ).thenAnswer((_) async => needs);

      await provider.fetchReplenishmentNeeds();

      expect(provider.isLoadingReplenishment, false);
      expect(provider.replenishmentNeeds, needs);
    });

    test('resetState clears all data', () {
      provider.resetState();
      expect(provider.stats.totalWarehouses, 0);
      expect(provider.recentActivities, isEmpty);
      expect(provider.negativeQuants, isEmpty);
    });
  });
}
