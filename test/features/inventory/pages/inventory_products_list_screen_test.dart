import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_inv_app/features/inventory/models/inventory_product.dart';
import 'package:mobo_inv_app/features/inventory/pages/inventory_products_list_screen.dart';
import '../mocks/mock.dart';
import '../helpers/test_wrapper.dart';

void main() {
  late MockInventoryProductProvider inventoryProductProvider;

  setUp(() {
    inventoryProductProvider = MockInventoryProductProvider();
    registerFallbackValue(FakeBuildContext());

    // Default mocks
    when(() => inventoryProductProvider.isLoading).thenReturn(false);
    when(() => inventoryProductProvider.hasLoadedOnce).thenReturn(true);
    when(() => inventoryProductProvider.error).thenReturn(null);
    when(() => inventoryProductProvider.products).thenReturn([]);
    when(() => inventoryProductProvider.groupByOptions).thenReturn({});
    when(
      () => inventoryProductProvider.fetchProducts(),
    ).thenAnswer((_) async {});
    when(
      () => inventoryProductProvider.fetchCategories(),
    ).thenAnswer((_) async {});
    when(
      () => inventoryProductProvider.fetchGroupByOptions(),
    ).thenAnswer((_) async {});
    when(() => inventoryProductProvider.totalProducts).thenReturn(0);
    when(() => inventoryProductProvider.canGoToPreviousPage).thenReturn(false);
    when(() => inventoryProductProvider.canGoToNextPage).thenReturn(false);
    when(
      () => inventoryProductProvider.getPaginationText(),
    ).thenReturn('0 items');

    // Filters
    when(() => inventoryProductProvider.selectedCategories).thenReturn([]);
    when(() => inventoryProductProvider.inStockOnly).thenReturn(null);
    when(() => inventoryProductProvider.productType).thenReturn(null);
    when(() => inventoryProductProvider.isStorable).thenReturn(true);
    when(() => inventoryProductProvider.availableInPos).thenReturn(null);
    when(() => inventoryProductProvider.saleOk).thenReturn(null);
    when(() => inventoryProductProvider.purchaseOk).thenReturn(null);
    when(() => inventoryProductProvider.hasActivityException).thenReturn(null);
    when(() => inventoryProductProvider.isActive).thenReturn(true);
    when(() => inventoryProductProvider.hasNegativeStock).thenReturn(null);

    // Grouping
    when(() => inventoryProductProvider.selectedGroupBy).thenReturn(null);
    when(() => inventoryProductProvider.isGrouped).thenReturn(false);
    when(() => inventoryProductProvider.groupSummary).thenReturn({});
  });

  testWidgets('InventoryProductsListScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWithProviders(
        child: const InventoryProductsListScreen(),
        inventoryProductProvider: inventoryProductProvider,
      ),
    );

    expect(find.byType(InventoryProductsListScreen), findsOneWidget);
  });

  testWidgets('Displays products when available', (WidgetTester tester) async {
    final fakeProducts = [
      InventoryProduct(
        id: 1,
        name: 'Product A',
        displayname: 'Product A',
        defaultCode: 'A001',
        qtyOnHand: 10.0,
        qtyIncoming: 0.0,
        qtyOutgoing: 0.0,
        qtyAvailable: 10.0,
        freeQty: 10.0,
        avgCost: 100.0,
        totalValue: 1000.0,
      ),
      InventoryProduct(
        id: 2,
        name: 'Product B',
        displayname: 'Product B',
        defaultCode: 'B001',
        qtyOnHand: 5.0,
        qtyIncoming: 0.0,
        qtyOutgoing: 0.0,
        qtyAvailable: 5.0,
        freeQty: 5.0,
        avgCost: 200.0,
        totalValue: 1000.0,
      ),
    ];

    when(() => inventoryProductProvider.products).thenReturn(fakeProducts);
    when(() => inventoryProductProvider.totalProducts).thenReturn(2);
    when(
      () => inventoryProductProvider.getPaginationText(),
    ).thenReturn('2 items');

    await tester.pumpWidget(
      wrapWithProviders(
        child: const InventoryProductsListScreen(),
        inventoryProductProvider: inventoryProductProvider,
      ),
    );

    await tester.pump(); // frame

    expect(find.text('Product A'), findsOneWidget);
    expect(find.text('Product B'), findsOneWidget);
  });

  testWidgets('Displays empty state when no products found', (
    WidgetTester tester,
  ) async {
    when(() => inventoryProductProvider.products).thenReturn([]);

    await tester.pumpWidget(
      wrapWithProviders(
        child: const InventoryProductsListScreen(),
        inventoryProductProvider: inventoryProductProvider,
      ),
    );

    await tester.pump();

    expect(find.text('No products found'), findsOneWidget);
  });
}
