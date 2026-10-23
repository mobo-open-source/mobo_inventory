import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_inv_app/core/routing/app_routes.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/inventory/models/inventory_product.dart';
import 'package:mobo_inv_app/features/inventory/pages/inventory_products_list_screen.dart';
import 'package:mobo_inv_app/features/inventory/providers/inventory_product_provider.dart';
import 'package:mobo_inv_app/features/inventory/widgets/inventory_product_kanban_card.dart';
import 'package:mobo_inv_app/features/inventory/widgets/inventory_product_list_tile.dart';
import 'package:mobo_inv_app/shared/widgets/search/mobo_search_filter_bar.dart';

import '../helpers/fake_access.dart';
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

/// A variant: [name] is the template's, [displayname] adds the attribute
/// values the way Odoo's `display_name` does.
InventoryProduct _variant(int id, String name, String displayname) =>
    InventoryProduct(
      id: id,
      name: name,
      displayname: displayname,
      qtyOnHand: 0,
      qtyIncoming: 0,
      qtyOutgoing: 0,
      qtyAvailable: 0,
      freeQty: 0,
      avgCost: 0,
      totalValue: 0,
      listPrice: 1799,
      uomId: const [1, 'Units'],
      categId: const [1, 'Goods'],
    );

final _products = [for (var i = 1; i <= 6; i++) _product(i, 'Product $i')];

/// Pushed routes land on a stub page that names its route and arguments.
Widget _app(InventoryProductProvider provider, {AccessRightsService? access}) {
  Widget stub(String name, GoRouterState state) =>
      Scaffold(body: Text('$name ${state.extra}'));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const InventoryProductsListScreen(),
      ),
      GoRoute(
        name: AppRoutes.inventoryProductDetail,
        path: AppRoutes.inventoryProductDetail,
        builder: (_, s) => stub('detail', s),
      ),
      GoRoute(
        name: AppRoutes.inventoryProductEdit,
        path: AppRoutes.inventoryProductEdit,
        builder: (_, s) => stub('edit', s),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<InventoryProductProvider>.value(value: provider),
      if (access != null)
        ChangeNotifierProvider<AccessRightsService>.value(value: access),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _showKanban(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('inventoryViewToggleKanban')));
  await tester.pumpAndSettle();
}

int _gridColumns(WidgetTester tester, Finder grid) {
  final view = tester.widget<GridView>(grid);
  return (view.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

void main() {
  late MockInventoryProductProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = MockInventoryProductProvider();

    when(() => provider.isLoading).thenReturn(false);
    when(() => provider.hasLoadedOnce).thenReturn(true);
    when(() => provider.error).thenReturn(null);
    when(() => provider.products).thenReturn(_products);
    when(() => provider.groupByOptions).thenReturn({'categ_id': 'Category'});
    when(() => provider.fetchProducts()).thenAnswer((_) async {});
    when(
      () => provider.fetchProducts(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async {});
    when(() => provider.fetchCategories()).thenAnswer((_) async {});
    when(() => provider.fetchGroupByOptions()).thenAnswer((_) async {});
    when(() => provider.fetchGroupSummary()).thenAnswer((_) async {});
    when(() => provider.loadGroupProducts(any())).thenAnswer((_) async {});
    when(() => provider.totalProducts).thenReturn(_products.length);
    when(() => provider.canGoToPreviousPage).thenReturn(false);
    when(() => provider.canGoToNextPage).thenReturn(false);
    when(() => provider.getPaginationText()).thenReturn('1-6/6');

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

  void grouped({int groups = 8}) {
    when(() => provider.selectedGroupBy).thenReturn('categ_id');
    when(() => provider.isGrouped).thenReturn(true);
    when(
      () => provider.groupSummary,
    ).thenReturn({for (var i = 1; i <= groups; i++) 'Category $i': i});
    when(() => provider.loadedGroups).thenReturn({
      'Category 1': [_products[0], _products[1]],
    });
  }

  group('kanban view', () {
    testWidgets('the toggle switches the list to a grid of cards', (
      tester,
    ) async {
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      expect(find.byType(InventoryProductListTile), findsWidgets);
      expect(find.byType(InventoryProductKanbanCard), findsNothing);

      await _showKanban(tester);

      expect(find.byType(InventoryProductListTile), findsNothing);
      expect(find.byType(InventoryProductKanbanCard), findsWidgets);
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('REF1'), findsOneWidget);
      expect(find.text('4.50'), findsWidgets);
      expect(tester.takeException(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('inventory_products_view_mode'), 'kanban');
    });

    testWidgets('column count follows the available width', (tester) async {
      final grid = find.byKey(const ValueKey('inventoryKanbanGrid'));

      _setScreen(tester, const Size(400, 800)); // portrait phone
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);
      expect(_gridColumns(tester, grid), 2);

      _setScreen(tester, const Size(860, 400)); // landscape phone
      await tester.pumpAndSettle();
      expect(_gridColumns(tester, grid), 4);

      _setScreen(tester, const Size(1280, 800)); // landscape tablet
      await tester.pumpAndSettle();
      expect(_gridColumns(tester, grid), 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text grows the cards instead of overflowing', (
      tester,
    ) async {
      _setScreen(tester, const Size(360, 740));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a card opens the product detail', (tester) async {
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);

      await tester.tap(find.text('Product 2'));
      await tester.pumpAndSettle();

      expect(find.text('detail {productId: 2}'), findsOneWidget);
    });

    testWidgets('cards keep the row actions menu', (tester) async {
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);

      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('inventoryKanbanCard_1')),
              matching: find.byIcon(Icons.more_vert),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Locate'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('grouped: a column per group, scrolled sideways, as in Odoo', (
      tester,
    ) async {
      grouped(groups: 2);
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);

      final board = find.byKey(const ValueKey('kanbanBoard'));
      expect(tester.widget<ListView>(board).scrollDirection, Axis.horizontal);
      final column = find.byKey(const ValueKey('kanbanColumn_Category 1'));
      expect(column, findsOneWidget);
      // The header carries the group's count from the server, in brackets.
      expect(
        find.descendant(of: column, matching: find.text('(1)')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: column,
          matching: find.byType(InventoryProductKanbanCard),
        ),
        findsNWidgets(2),
      );
      // Odoo shows no pager on a grouped kanban.
      expect(find.text('1-2/2'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('create product button', () {
    testWidgets('opens the product form in create mode', (tester) async {
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      final fab = find.byTooltip('Create Product');
      expect(fab, findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .heroTag,
        'createInventoryProductFab',
      );

      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('edit {create: true}'), findsOneWidget);
    });

    testWidgets('leaves room under the last item', (tester) async {
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(find.byType(ListView).last);
      expect((list.padding as EdgeInsets).bottom, greaterThanOrEqualTo(88));
    });

    testWidgets('shows for a user Odoo lets create products', (tester) async {
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider, access: fakeAccess()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('is hidden without create rights', (tester) async {
      _setScreen(tester, const Size(400, 800));
      final access = fakeAccess(denied: {'product.product|create'});
      await tester.pumpWidget(_app(provider, access: access));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('group by', () {
    testWidgets('grouped list tiles open the product detail', (tester) async {
      grouped(groups: 2);
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product 2'));
      await tester.pumpAndSettle();

      expect(find.text('detail {productId: 2}'), findsOneWidget);
    });

    testWidgets('grouped list keeps a variant\'s attribute values', (
      tester,
    ) async {
      grouped(groups: 2);
      when(() => provider.loadedGroups).thenReturn({
        'Category 1': [_variant(7, 'Large Desk', 'Large Desk (Wood)')],
      });
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category 1'));
      await tester.pumpAndSettle();

      expect(find.text('Large Desk (Wood)'), findsOneWidget);
      expect(find.text('Large Desk'), findsNothing);
    });

    testWidgets('grouped kanban keeps a variant\'s attribute values', (
      tester,
    ) async {
      grouped(groups: 2);
      when(() => provider.loadedGroups).thenReturn({
        'Category 1': [_variant(7, 'Large Desk', 'Large Desk (Wood)')],
      });
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);

      expect(find.text('Large Desk (Wood)'), findsOneWidget);
      expect(find.text('Large Desk'), findsNothing);
    });

    testWidgets('portrait keeps the header and group summary pinned', (
      tester,
    ) async {
      grouped();
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      expect(find.byType(NestedScrollView), findsNothing);
      final list = find.byKey(const ValueKey('inventoryGroupedList'));
      final summary = find.byKey(const ValueKey('inventoryGroupSummaryRow'));
      expect(summary, findsOneWidget);
      expect(find.descendant(of: list, matching: summary), findsNothing);
    });

    testWidgets(
      'landscape phone: header and group summary scroll away with the list',
      (tester) async {
        grouped();
        _setScreen(tester, const Size(800, 360));
        await tester.pumpWidget(_app(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(NestedScrollView), findsOneWidget);

        final list = find.byKey(const ValueKey('inventoryGroupedList'));
        final summary = find.byKey(const ValueKey('inventoryGroupSummaryRow'));
        // The "N groups / Expand All" row is the list's first item.
        expect(find.descendant(of: list, matching: summary), findsOneWidget);

        expect(find.byType(MoboSearchFilterBar), findsOneWidget);
        await tester.drag(list, const Offset(0, -300));
        await tester.pumpAndSettle();

        // The search bar went up and off screen with the list, leaving the
        // short screen to the groups.
        expect(find.byType(MoboSearchFilterBar), findsNothing);
        expect(
          find.byType(MoboSearchFilterBar, skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('landscape phone kanban grouped renders without overflow', (
      tester,
    ) async {
      grouped();
      _setScreen(tester, const Size(800, 360));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();
      await _showKanban(tester);

      expect(find.byKey(const ValueKey('kanbanBoard')), findsOneWidget);
      expect(find.byType(InventoryProductKanbanCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets("a grouped list's pager counts groups, as Odoo's does", (
      tester,
    ) async {
      grouped(groups: 3);
      _setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(_app(provider));
      await tester.pumpAndSettle();

      expect(find.text('1-3/3'), findsOneWidget);
      // Not the products' pager.
      expect(find.text('1-6/6'), findsNothing);
    });
  });

  group('stock count action', () {
    testWidgets('"Edit" is withheld without stock.quant write', (tester) async {
      _setScreen(tester, const Size(400, 800));
      final access = fakeAccess(denied: {'stock.quant|write'});
      await tester.pumpWidget(_app(provider, access: access));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('Locate'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a row with no action left has no menu trigger', (
      tester,
    ) async {
      // Nothing on hand (no "Locate") and no right to count stock.
      when(() => provider.products).thenReturn([
        InventoryProduct(
          id: 9,
          name: 'Empty shelf',
          displayname: 'Empty shelf',
          qtyOnHand: 0,
          qtyIncoming: 0,
          qtyOutgoing: 0,
          qtyAvailable: 0,
          freeQty: 0,
          avgCost: 0,
          totalValue: 0,
        ),
      ]);
      _setScreen(tester, const Size(400, 800));
      final access = fakeAccess(denied: {'stock.quant|write'});
      await tester.pumpWidget(_app(provider, access: access));
      await tester.pumpAndSettle();

      expect(find.text('Empty shelf'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      await _showKanban(tester);
      expect(find.byType(InventoryProductKanbanCard), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
