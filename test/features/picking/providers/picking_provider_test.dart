import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_inv_app/features/picking/providers/picking_provider.dart';
import 'package:mobo_inv_app/features/picking/services/picking_service.dart';
import 'package:mobo_inv_app/features/picking/models/picking_model.dart';

class MockPickingService extends Mock implements PickingService {}

void main() {
  late PickingProvider provider;
  late MockPickingService mockService;
  const testPickingCode = 'incoming';

  setUp(() {
    mockService = MockPickingService();
    provider = PickingProvider(
      pickingTypeCode: testPickingCode,
      service: mockService,
    );
  });

  group('PickingProvider Tests', () {
    test('Initial state is correct', () {
      expect(provider.isLoading, false);
      expect(provider.items, isEmpty);
      expect(provider.pickingTypeCode, testPickingCode);
    });

    test('fetchPickings success', () async {
      final pickings = [
        Picking(
          id: 1,
          name: 'WH/IN/001',
          state: 'assigned',
          pickingTypeCode: 'incoming',
          pickingTypeName: 'Receipts',
          scheduledDate: '2023-01-01',
        ),
      ];

      when(
        () => mockService.fetchPickings(
          pickingTypeCode: any(named: 'pickingTypeCode'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          searchQuery: any(named: 'searchQuery'),
          states: any(named: 'states'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => pickings);

      when(
        () => mockService.getPickingCount(
          pickingTypeCode: any(named: 'pickingTypeCode'),
          searchQuery: any(named: 'searchQuery'),
          states: any(named: 'states'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => 1);

      when(
        () => mockService.cachePickings(any(), any()),
      ).thenAnswer((_) async {});

      await provider.fetchPickings();

      expect(provider.isLoading, false);
      expect(provider.items, pickings);
      expect(provider.totalCount, 1);
      expect(provider.hasLoadedOnce, true);
    });

    test('fetchPickings failure', () async {
      when(
        () => mockService.fetchPickings(
          pickingTypeCode: any(named: 'pickingTypeCode'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          searchQuery: any(named: 'searchQuery'),
          states: any(named: 'states'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('Failed'));

      await provider.fetchPickings();

      expect(provider.isLoading, false);
      expect(provider.items, isEmpty);
      expect(provider.error, isNotNull);
    });

    test('fetchGroupSummary success', () async {
      provider.setGroupBy('state');
      final summary = {'assigned': 5, 'done': 10};

      when(
        () => mockService.loadCachedGroupSummary(any(), any()),
      ).thenAnswer((_) async => {});

      when(
        () => mockService.fetchGroupSummary(
          pickingTypeCode: any(named: 'pickingTypeCode'),
          groupByField: any(named: 'groupByField'),
          searchQuery: any(named: 'searchQuery'),
          states: any(named: 'states'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => summary);

      when(
        () => mockService.cacheGroupSummary(any(), any(), any()),
      ).thenAnswer((_) async {});

      await provider.fetchGroupSummary();

      expect(provider.groupSummary, summary);
    });

    test('Pagination logic', () {
      // Mock internal state manually for simplicity or use reflection if needed,
      // but here we can just check initial logic
      expect(provider.currentPage, 0);
      expect(provider.canGoToPreviousPage, false);
      // Since total count is 0
      expect(provider.canGoToNextPage, false);
    });

    test('Filtering updates state', () {
      provider.fetchPickings(searchQuery: 'test', states: ['done']);
      expect(provider.searchQuery, 'test');
      expect(provider.states, ['done']);
    });

    test('clearFilters resets state', () {
      provider.fetchPickings(searchQuery: 'test');
      provider.setGroupBy('state');

      provider.clearFilters();

      expect(provider.searchQuery, '');
      expect(provider.selectedGroupBy, null);
      expect(provider.groupSummary, isEmpty);
    });
  });
}
