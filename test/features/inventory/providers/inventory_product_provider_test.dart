import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_inv_app/features/inventory/providers/inventory_product_provider.dart';
import 'package:mobo_inv_app/features/inventory/services/inventory_product_service.dart';
import 'package:mobo_inv_app/features/inventory/services/inventory_group_service.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mobo_inv_app/core/models/appsession.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_inv_app/features/inventory/models/inventory_product.dart';

class MockInventoryProductService extends Mock
    implements InventoryProductService {}

class MockInventoryGroupService extends Mock implements InventoryGroupService {}

class MockOdooClient extends Mock implements OdooClient {}

class MockOdooSession extends Mock implements OdooSession {}

class MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  late InventoryProductProvider provider;
  late MockInventoryProductService mockService;
  late MockInventoryGroupService mockGroupService;
  late MockOdooClient mockClient;
  late MockSecureStorage mockSecureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    mockService = MockInventoryProductService();
    mockGroupService = MockInventoryGroupService();
    mockClient = MockOdooClient();
    mockSecureStorage = MockSecureStorage();

    SecureStorageService.setInstanceForTesting(mockSecureStorage);
    when(
      () => mockSecureStorage.storePassword(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockSecureStorage.getPassword(any()),
    ).thenAnswer((_) async => 'pw');

    // Setup OdooSessionManager to return our mock client
    OdooSessionManager.setClientForTesting(mockClient);

    // Mock the session to be valid so getClientEnsured works
    final odooSession = OdooSession(
      id: 'sess',
      userId: 1,
      partnerId: 1,
      companyId: 1,
      allowedCompanies: [],
      userLogin: 'test',
      userName: 'Test',
      userLang: 'en',
      userTz: 'UTC',
      isSystem: false,
      dbName: 'db',
      serverVersion: '16',
    );
    final sessionData = AppSessionData(
      odooSession: odooSession,
      password: 'pw',
      serverUrl: 'http://test',
      database: 'db',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    await sessionData.saveToPrefs();
    await OdooSessionManager.updateSession(sessionData);

    // Mock OdooMetadataService calls (ir.model check) via the client
    // It calls callKw on ir.model search_count
    registerFallbackValue({});
    when(() => mockClient.callKw(any())).thenAnswer((invocation) async {
      final args = invocation.positionalArguments[0] as Map<String, dynamic>;
      if (args['model'] == 'ir.model' && args['method'] == 'search_count') {
        // Check if searching for product.product
        final searchArgs = args['args'] as List;
        if (searchArgs.isNotEmpty && searchArgs[0] is List) {
          final domain = searchArgs[0] as List;
          if (domain.isNotEmpty &&
              domain[0] is List &&
              domain[0][0] == 'model' &&
              domain[0][2] == 'product.product') {
            return 1;
          }
        }
        return 1; // Default true for mocks
      }
      return [];
    });

    provider = InventoryProductProvider(
      service: mockService,
      groupService: mockGroupService,
    );
  });

  tearDown(() {
    OdooSessionManager.resetForTesting();
  });

  group('InventoryProductProvider', () {
    test('initial state is correct', () {
      expect(provider.products, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.hasMoreData, true); // Default is true
    });

    test('fetchProducts success', () async {
      final products = [
        InventoryProduct(
          id: 1,
          name: 'P1',
          displayname: 'Product 1',
          qtyOnHand: 10,
          qtyIncoming: 0,
          qtyOutgoing: 0,
          qtyAvailable: 10,
          freeQty: 10,
          avgCost: 100,
          totalValue: 1000,
        ),
      ];

      when(
        () => mockService.fetchProducts(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenAnswer((_) async => products);

      when(
        () => mockService.getProductCount(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenAnswer((_) async => 1);

      await provider.fetchProducts();

      expect(provider.isLoading, false);
      expect(provider.products, isNotEmpty);
      expect(provider.products.first.name, 'P1');
      expect(provider.totalProducts, 1);
    });

    test('a search keeps the filters applied', () async {
      when(
        () => mockService.fetchProducts(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockService.getProductCount(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenAnswer((_) async => 0);

      await provider.applyFilters(productType: 'consu', isStorable: true);
      await provider.fetchProducts(searchQuery: 'desk');

      expect(provider.productType, 'consu');
      expect(provider.isStorable, true);
      verify(
        () => mockService.getProductCount(
          searchQuery: 'desk',
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          productType: 'consu',
          isStorable: true,
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).called(1);
    });

    test('fetchProducts handles failure', () async {
      when(
        () => mockService.fetchProducts(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenThrow(Exception('Network Error'));

      await provider.fetchProducts();

      expect(provider.isLoading, false);
      expect(provider.products, isEmpty);
      expect(provider.error, isNotNull);
    });

    test('setGroupBy updates state', () {
      provider.setGroupBy('categ_id');
      expect(provider.selectedGroupBy, 'categ_id');
      expect(provider.isGrouped, true);

      provider.setGroupBy(null);
      expect(provider.selectedGroupBy, null);
      expect(provider.isGrouped, false);
    });

    test('fetchGroupSummary success', () async {
      provider.setGroupBy('categ_id');
      when(
        () => mockGroupService.fetchGroupSummary(
          groupByField: 'categ_id',
          domain: any(named: 'domain'),
          domainsOut: any(named: 'domainsOut'),
          typeLabels: any(named: 'typeLabels'),
        ),
      ).thenAnswer((_) async => {'Category A': 5, 'Category B': 3});

      await provider.fetchGroupSummary();

      expect(provider.groupSummary.length, 2);
      expect(provider.groupSummary['Category A'], 5);
    });
  });

  group('a newer search wins over a slower, older one', () {
    InventoryProduct product(int id, String name) => InventoryProduct(
      id: id,
      name: name,
      displayname: name,
      qtyOnHand: 1,
      qtyIncoming: 0,
      qtyOutgoing: 0,
      qtyAvailable: 1,
      freeQty: 1,
      avgCost: 1,
      totalValue: 1,
    );

    /// Serves `fetchProducts` through [answer], by the query it was asked for.
    void serveProducts(
      Future<List<InventoryProduct>> Function(String? query) answer,
    ) {
      when(
        () => mockService.fetchProducts(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenAnswer(
        (invocation) =>
            answer(invocation.namedArguments[#searchQuery] as String?),
      );
      when(
        () => mockService.getProductCount(
          searchQuery: any(named: 'searchQuery'),
          categoryIds: any(named: 'categoryIds'),
          inStockOnly: any(named: 'inStockOnly'),
          productType: any(named: 'productType'),
          isStorable: any(named: 'isStorable'),
          isActive: any(named: 'isActive'),
          availableInPos: any(named: 'availableInPos'),
          saleOk: any(named: 'saleOk'),
          purchaseOk: any(named: 'purchaseOk'),
          hasActivityException: any(named: 'hasActivityException'),
          hasNegativeStock: any(named: 'hasNegativeStock'),
        ),
      ).thenAnswer((_) async => 1);
    }

    test('a slow search cannot overwrite the search cleared after it', () async {
      final slowDesk = Completer<List<InventoryProduct>>();
      serveProducts(
        (query) =>
            query == 'desk' ? slowDesk.future : Future.value([product(1, 'All')]),
      );

      // Searched, then cleared before the search came back.
      final desk = provider.fetchProducts(
        searchQuery: 'desk',
        forceRefresh: true,
      );
      await provider.fetchProducts(searchQuery: '', forceRefresh: true);
      expect(provider.products.map((p) => p.name), ['All']);

      slowDesk.complete([product(2, 'Desk')]);
      await desk;

      // The old search's answer is dropped: the list still matches the
      // empty search the field shows.
      expect(provider.searchQuery, '');
      expect(provider.products.map((p) => p.name), ['All']);
      expect(provider.isLoading, false);
    });

    test('an older fetch finishing does not end the newer one loading', () async {
      final slowDesk = Completer<List<InventoryProduct>>();
      final slowAll = Completer<List<InventoryProduct>>();
      serveProducts(
        (query) => query == 'desk' ? slowDesk.future : slowAll.future,
      );

      final desk = provider.fetchProducts(
        searchQuery: 'desk',
        forceRefresh: true,
      );
      final all = provider.fetchProducts(searchQuery: '', forceRefresh: true);

      slowDesk.complete([product(2, 'Desk')]);
      await desk;
      // The newer search has not answered: still loading, nothing shown.
      expect(provider.isLoading, true);
      expect(provider.products, isEmpty);

      slowAll.complete([product(1, 'All')]);
      await all;
      expect(provider.isLoading, false);
      expect(provider.products.map((p) => p.name), ['All']);
    });

    test('a group summary overtaken by a newer one is dropped', () async {
      provider.setGroupBy('categ_id');
      final slow = Completer<Map<String, int>>();
      var calls = 0;
      when(
        () => mockGroupService.fetchGroupSummary(
          groupByField: 'categ_id',
          domain: any(named: 'domain'),
          domainsOut: any(named: 'domainsOut'),
          typeLabels: any(named: 'typeLabels'),
        ),
      ).thenAnswer(
        (_) => ++calls == 1 ? slow.future : Future.value({'A': 5, 'B': 3}),
      );

      final searched = provider.fetchGroupSummary(); // the old search's groups
      await provider.fetchGroupSummary(); // after the search was cleared
      expect(provider.groupSummary, {'A': 5, 'B': 3});

      slow.complete({'Desks': 1});
      await searched;
      expect(provider.groupSummary, {'A': 5, 'B': 3});
    });

    test('a summary landing after ungrouping does not bring the groups back', () async {
      provider.setGroupBy('categ_id');
      final slow = Completer<Map<String, int>>();
      when(
        () => mockGroupService.fetchGroupSummary(
          groupByField: 'categ_id',
          domain: any(named: 'domain'),
          domainsOut: any(named: 'domainsOut'),
          typeLabels: any(named: 'typeLabels'),
        ),
      ).thenAnswer((_) => slow.future);

      final summary = provider.fetchGroupSummary();
      provider.setGroupBy(null);
      slow.complete({'A': 5});
      await summary;

      expect(provider.groupSummary, isEmpty);
    });

    test('products loaded for a group the summary since replaced are dropped', () async {
      provider.setGroupBy('categ_id');
      var summaries = 0;
      when(
        () => mockGroupService.fetchGroupSummary(
          groupByField: 'categ_id',
          domain: any(named: 'domain'),
          domainsOut: any(named: 'domainsOut'),
          typeLabels: any(named: 'typeLabels'),
        ),
      ).thenAnswer((invocation) async {
        // Each summary hands out its own domain for the group, as Odoo does.
        final out =
            invocation.namedArguments[#domainsOut]
                as Map<String, List<dynamic>>?;
        out?['A'] = [
          ['search', '=', ++summaries],
        ];
        return {'A': 1};
      });
      final slowLoad = Completer<List<InventoryProduct>>();
      when(
        () => mockGroupService.fetchGroupProducts(
          domain: any(named: 'domain'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => slowLoad.future);

      await provider.fetchGroupSummary();
      final load = provider.loadGroupProducts('A');
      // The search changes and the groups are summarised afresh meanwhile.
      await provider.fetchGroupSummary();

      slowLoad.complete([product(2, 'Desk')]);
      await load;

      expect(provider.loadedGroups.containsKey('A'), false);
    });
  });
}
