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
          categories: any(named: 'categories'),
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
          categories: any(named: 'categories'),
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

    test('fetchProducts handles failure', () async {
      when(
        () => mockService.fetchProducts(
          searchQuery: any(named: 'searchQuery'),
          categories: any(named: 'categories'),
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
          searchQuery: any(named: 'searchQuery'),
          categories: any(named: 'categories'),
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
      ).thenAnswer((_) async => {'Category A': 5, 'Category B': 3});

      await provider.fetchGroupSummary();

      expect(provider.groupSummary.length, 2);
      expect(provider.groupSummary['Category A'], 5);
    });
  });
}
