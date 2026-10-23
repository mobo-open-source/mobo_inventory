import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/inventory/models/inventory_product.dart';
import 'package:mobo_inv_app/features/inventory/pages/inventory_products_list_screen.dart';
import 'package:mobo_inv_app/shared/widgets/search/mobo_search_filter_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_wrapper.dart';
import '../mocks/mock.dart';

InventoryProduct _product(int id, String name) => InventoryProduct(
  id: id,
  name: name,
  displayname: name,
  defaultCode: 'REF$id',
  qtyOnHand: 10,
  qtyIncoming: 0,
  qtyOutgoing: 0,
  qtyAvailable: 10,
  freeQty: 8,
  avgCost: 2,
  totalValue: 20,
  listPrice: 4.5,
  uomId: const [1, 'Units'],
  categId: const [1, 'Goods'],
);

final _products = [for (var i = 1; i <= 3; i++) _product(i, 'Product $i')];

const _debounce = Duration(milliseconds: 600);

void main() {
  late MockInventoryProductProvider provider;

  /// The search the (mock) provider holds, as the real one does after a
  /// `fetchProducts(searchQuery: …)`.
  late String applied;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = MockInventoryProductProvider();
    applied = '';

    when(() => provider.isLoading).thenReturn(false);
    when(() => provider.hasLoadedOnce).thenReturn(true);
    when(() => provider.error).thenReturn(null);
    when(() => provider.products).thenReturn(_products);
    when(() => provider.groupByOptions).thenReturn({'categ_id': 'Category'});
    when(() => provider.searchQuery).thenAnswer((_) => applied);
    when(
      () => provider.fetchProducts(
        searchQuery: any(named: 'searchQuery'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((invocation) async {
      applied = invocation.namedArguments[#searchQuery] as String? ?? applied;
    });
    when(() => provider.fetchCategories()).thenAnswer((_) async {});
    when(() => provider.fetchGroupByOptions()).thenAnswer((_) async {});
    when(() => provider.fetchGroupSummary()).thenAnswer((_) async {});
    when(() => provider.loadGroupProducts(any())).thenAnswer((_) async {});
    when(() => provider.totalProducts).thenReturn(_products.length);
    when(() => provider.canGoToPreviousPage).thenReturn(false);
    when(() => provider.canGoToNextPage).thenReturn(false);
    when(() => provider.getPaginationText()).thenReturn('1-3/3');

    when(() => provider.selectedCategories).thenReturn([]);
    when(() => provider.inStockOnly).thenReturn(null);
    when(() => provider.productType).thenReturn(null);
    when(() => provider.isStorable).thenReturn(null);
    when(() => provider.availableInPos).thenReturn(null);
    when(() => provider.saleOk).thenReturn(null);
    when(() => provider.purchaseOk).thenReturn(null);
    when(() => provider.hasActivityException).thenReturn(null);
    when(() => provider.isActive).thenReturn(true);
    when(() => provider.hasNegativeStock).thenReturn(null);

    when(() => provider.selectedGroupBy).thenReturn(null);
    when(() => provider.isGrouped).thenReturn(false);
    when(() => provider.groupSummary).thenReturn({});
    when(() => provider.loadedGroups).thenReturn({});
  });

  void grouped(Map<String, int> groups) {
    when(() => provider.selectedGroupBy).thenReturn('categ_id');
    when(() => provider.isGrouped).thenReturn(true);
    when(() => provider.groupSummary).thenReturn(groups);
    when(() => provider.loadedGroups).thenReturn({
      'Category 1': [_products[0], _products[1]],
    });
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithProviders(
        child: const InventoryProductsListScreen(),
        inventoryProductProvider: provider,
      ),
    );
    await tester.pump();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(_debounce);
  }

  // The "x" of the search field.
  final clearButton = find.descendant(
    of: find.byType(MoboSearchFilterBar),
    matching: find.byType(IconButton),
  );

  group('search while grouped', () {
    testWidgets('a search summarises the groups afresh', (tester) async {
      grouped({'Category 1': 2, 'Category 2': 1});
      await open(tester);

      await search(tester, 'desk');

      verify(
        () => provider.fetchProducts(searchQuery: 'desk', forceRefresh: true),
      ).called(1);
      // The groups, not only the flat list, are searched: they are what a
      // grouped screen shows.
      verify(() => provider.fetchGroupSummary()).called(1);
    });

    testWidgets('clearing the search with the x brings every group back', (
      tester,
    ) async {
      grouped({'Category 1': 2, 'Category 2': 1});
      await open(tester);

      await search(tester, 'desk');
      await tester.tap(clearButton);
      await tester.pump(_debounce);

      verify(
        () => provider.fetchProducts(searchQuery: '', forceRefresh: true),
      ).called(1);
      verify(() => provider.fetchGroupSummary()).called(2);
    });

    testWidgets('a group the search dropped comes back closed', (tester) async {
      grouped({'Category 1': 2, 'Category 2': 1});
      await open(tester);

      await tester.tap(find.text('Category 1'));
      await tester.pump();
      // One group is open, so the summary row offers to collapse.
      expect(find.text('Collapse All'), findsOneWidget);

      // A search leaves only 'Category 2' (the screen rebuilds as it types),
      // then the search is cleared and 'Category 1' is back.
      when(() => provider.groupSummary).thenReturn({'Category 2': 1});
      await search(tester, 'desk');
      when(
        () => provider.groupSummary,
      ).thenReturn({'Category 1': 2, 'Category 2': 1});
      await search(tester, '');

      // Back closed — not open on a list that was never reloaded.
      expect(find.text('Collapse All'), findsNothing);
      expect(find.text('Expand All'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('a flat list has no groups to summarise', (tester) async {
      await open(tester);

      await search(tester, 'desk');

      verify(
        () => provider.fetchProducts(searchQuery: 'desk', forceRefresh: true),
      ).called(1);
      verifyNever(() => provider.fetchGroupSummary());
    });

    testWidgets('moving the cursor is not a new search', (tester) async {
      await open(tester);

      await search(tester, 'desk');
      // Tapping into the field notifies its listeners without a new text.
      tester.widget<TextField>(find.byType(TextField)).controller!.selection =
          const TextSelection.collapsed(offset: 0);
      await tester.pump(_debounce);

      verify(
        () => provider.fetchProducts(
          searchQuery: any(named: 'searchQuery'),
          forceRefresh: true,
        ),
      ).called(1);
    });

    testWidgets('Clear All Filters also clears the search', (tester) async {
      // Nothing matches, whatever is searched.
      when(() => provider.products).thenReturn([]);
      when(() => provider.totalProducts).thenReturn(0);
      await open(tester);
      expect(find.text('No products found'), findsOneWidget);
      expect(find.text('Clear All Filters'), findsNothing); // nothing to clear

      await search(tester, 'zzz');

      // The search itself is something to clear.
      final clearAll = find.text('Clear All Filters');
      expect(clearAll, findsOneWidget);
      await tester.ensureVisible(clearAll);
      await tester.tap(clearAll);
      await tester.pump(_debounce);

      verify(() => provider.clearFilters()).called(1);
      verify(
        () => provider.fetchProducts(searchQuery: '', forceRefresh: true),
      ).called(1);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });
}
