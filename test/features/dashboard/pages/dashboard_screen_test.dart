import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobo_inv_app/core/routing/app_routes.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/core/services/session_service.dart';
import 'package:mobo_inv_app/features/company/providers/company_provider.dart';
import 'package:mobo_inv_app/features/dashboard/models/dashboard_stats.dart';
import 'package:mobo_inv_app/features/dashboard/pages/dashboard_screen.dart';
import 'package:mobo_inv_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:mobo_inv_app/features/dashboard/providers/last_opened_provider.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/dashboard_stat_card.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/operations_today_summary.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/replenishment_needs_list.dart';
import 'package:mobo_inv_app/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_access.dart';

/// A [DashboardProvider] that serves fixed stats and never hits the network.
class _FakeDashboardProvider extends DashboardProvider {
  _FakeDashboardProvider(this.fakeStats);

  final DashboardStats fakeStats;
  int refreshCalls = 0;

  @override
  DashboardStats get stats => fakeStats;
  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedData => true;
  @override
  String? get error => null;

  @override
  Future<void> fetchStats({bool forceRefresh = false}) async {}
  @override
  Future<void> fetchTodayOperationsCounts({bool forceRefresh = false}) async {}
  @override
  Future<void> fetchRecentActivities({
    int limit = 10,
    bool forceRefresh = false,
  }) async {}
  @override
  Future<void> fetchNegativeQuants({
    int limit = 4,
    bool forceRefresh = false,
  }) async {}
  @override
  Future<void> fetchTodayActivities({
    int limit = 4,
    bool forceRefresh = false,
  }) async {}
  @override
  Future<void> fetchReplenishmentNeeds({
    int limit = 4,
    bool forceRefresh = false,
  }) async {}
  @override
  Future<void> refreshAll() async => refreshCalls++;
}

/// A [CompanyProvider] whose selection the test sets directly.
class _FakeCompanyProvider extends CompanyProvider {
  int? _selected;
  List<int> _allowed = [];
  bool _settling = false;

  @override
  int? get selectedCompanyId => _selected;
  @override
  List<int> get selectedAllowedCompanyIds => _allowed;
  @override
  bool get isLoading => _settling;
  @override
  List<Map<String, dynamic>> get companies => [
    {'id': 1, 'name': 'Main'},
  ];

  void settle(int? selected, List<int> allowed, {bool loading = false}) {
    _selected = selected;
    _allowed = allowed;
    _settling = loading;
    notifyListeners();
  }
}

DashboardStats _stats({
  bool showManufacturing = true,
  bool showPosOrders = false,
}) => DashboardStats(
  totalWarehouses: 1,
  totalLocations: 4,
  deliveryOrders: 28,
  readyToDeliver: 28,
  receipts: 9,
  readyToReceive: 9,
  internalTransfers: 0,
  readyToTransfer: 0,
  manufacturingOrders: 6,
  readyToProduce: 4,
  negativeQuants: 0,
  posOrders: 2,
  showManufacturing: showManufacturing,
  showPosOrders: showPosOrders,
);

Widget _app(
  DashboardProvider dashboard, {
  CompanyProvider? company,
  AccessRightsService? access,
  GoRouter? router,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
    ChangeNotifierProvider<AccessRightsService>.value(
      value: access ?? fakeDashboardAccess(),
    ),
    ChangeNotifierProvider<CompanyProvider>.value(
      value: company ?? _FakeCompanyProvider(),
    ),
    ChangeNotifierProvider<SessionService>.value(
      value: SessionService.instance,
    ),
    ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
    ChangeNotifierProvider<LastOpenedProvider>(
      create: (_) => LastOpenedProvider(),
    ),
  ],
  child: router == null
      ? const MaterialApp(home: DashboardScreen())
      : MaterialApp.router(routerConfig: router),
);

/// The dashboard, with each list a card can open as a stub page naming it.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
    for (final route in [
      AppRoutes.warehouseList,
      AppRoutes.locationList,
      AppRoutes.deliveryList,
      AppRoutes.receiptList,
      AppRoutes.internalTransferList,
      AppRoutes.posOrderList,
      AppRoutes.manufacturingList,
    ])
      GoRoute(
        name: route,
        path: route,
        builder: (_, __) => Scaffold(body: Text('opened $route')),
      ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the To Process counts and the MO card with mrp', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeDashboardProvider(_stats())));
    await tester.pump();

    expect(find.text('Delivery Orders'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('Internal Transfers'), findsOneWidget);
    expect(find.text('To Process'), findsNWidgets(3));
    expect(find.text('Manufacturing Orders'), findsOneWidget);
    expect(find.text('4 Ready'), findsOneWidget);
  });

  testWidgets('PoS Orders get a card of their own with Point of Sale', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeDashboardProvider(_stats())));
    await tester.pump();
    expect(find.text('PoS Orders'), findsNothing);

    await tester.pumpWidget(
      _app(_FakeDashboardProvider(_stats(showPosOrders: true))),
    );
    await tester.pump();
    expect(find.text('PoS Orders'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // Delivery Orders keeps its own count; the PoS ones aren't in it.
    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('hides the MO card without the Manufacturing module', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeDashboardProvider(_stats(showManufacturing: false))),
    );
    await tester.pump();

    expect(find.text('Manufacturing Orders'), findsNothing);
    expect(find.text('Internal Transfers'), findsOneWidget);
  });

  testWidgets('landscape phone: compact stat tiles, no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_FakeDashboardProvider(_stats())));
    await tester.pump();

    final tile = find.byType(DashboardStatCard).first;
    expect(tester.getSize(tile).height, 150);
    expect(tester.takeException(), isNull);
  });

  group('access rights', () {
    testWidgets('a user without Inventory rights sees no picking, MO or '
        'replenishment figures', (tester) async {
      final access = noInventoryRightsAccess();
      await tester.pumpWidget(
        _app(_FakeDashboardProvider(_stats()), access: access),
      );
      await tester.pumpAndSettle();

      // Odoo lets every internal user read warehouses and locations.
      expect(find.text('Total Warehouses'), findsOneWidget);
      expect(find.text('Locations'), findsOneWidget);
      expect(find.text('Delivery Orders'), findsNothing);
      expect(find.text('Receipts'), findsNothing);
      expect(find.text('Internal Transfers'), findsNothing);
      expect(find.text('Manufacturing Orders'), findsNothing);
      expect(find.byType(OperationsTodaySummary), findsNothing);
      expect(find.byType(ReplenishmentNeedsList), findsNothing);
    });

    testWidgets('no MO card without read access to manufacturing orders', (
      tester,
    ) async {
      final access = fakeDashboardAccess(unreadable: const {'mrp.production'});
      await tester.pumpWidget(
        _app(_FakeDashboardProvider(_stats()), access: access),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manufacturing Orders'), findsNothing);
      expect(find.text('Delivery Orders'), findsOneWidget);
    });
  });

  testWidgets('each card opens the list it counts', (tester) async {
    const cards = {
      'Total Warehouses': AppRoutes.warehouseList,
      'Locations': AppRoutes.locationList,
      'Delivery Orders': AppRoutes.deliveryList,
      'Receipts': AppRoutes.receiptList,
      'Internal Transfers': AppRoutes.internalTransferList,
      'PoS Orders': AppRoutes.posOrderList,
      'Manufacturing Orders': AppRoutes.manufacturingList,
    };
    for (final card in cards.entries) {
      await tester.pumpWidget(
        _app(
          _FakeDashboardProvider(_stats(showPosOrders: true)),
          router: _router(),
        ),
      );
      await tester.pumpAndSettle();

      // The grid is built lazily: scroll the lower cards into view.
      await tester.scrollUntilVisible(
        find.text(card.key),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.ensureVisible(find.text(card.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(card.key));
      await tester.pumpAndSettle();
      expect(
        find.text('opened ${card.value}'),
        findsOneWidget,
        reason: card.key,
      );
    }
  });

  testWidgets('reloads once the company scope settles on a new value', (
    tester,
  ) async {
    final dashboard = _FakeDashboardProvider(_stats());
    final company = _FakeCompanyProvider();
    await tester.pumpWidget(_app(dashboard, company: company));
    await tester.pump();
    expect(dashboard.refreshCalls, 0);

    // Still loading: not settled yet.
    company.settle(2, [2], loading: true);
    expect(dashboard.refreshCalls, 0);

    company.settle(2, [2]);
    expect(dashboard.refreshCalls, 1);

    // Same scope again (e.g. the company picker re-reading it): no reload.
    company.settle(2, [2]);
    expect(dashboard.refreshCalls, 1);

    company.settle(2, [1, 2]);
    expect(dashboard.refreshCalls, 2);
  });

  testWidgets('an odd number of cards: the last one spans the row, no gap '
      'beside it', (tester) async {
    tester.view.physicalSize = const Size(1200, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The test font makes every glyph a full em wide, so the other sections'
    // headings report overflows a real font does not have.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);

    // Warehouses, Locations, Delivery, Receipts, Internal, PoS and Manufacturing:
    // seven cards in two columns leave Manufacturing Orders alone in its row.
    await tester.pumpWidget(
      _app(_FakeDashboardProvider(_stats(showPosOrders: true))),
    );
    await tester.pump();

    Rect cardOf(String title) => tester.getRect(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(DashboardStatCard),
      ),
    );
    final internal = cardOf('Internal Transfers');
    final manufacturing = cardOf('Manufacturing Orders');

    expect(manufacturing.width, closeTo(internal.width * 2 + 12, 0.01));
    expect(manufacturing.left, internal.left);
    // Still the height of its neighbours, directly under their row.
    expect(manufacturing.height, closeTo(internal.height, 0.01));
    expect(manufacturing.top, closeTo(internal.bottom + 12, 0.01));
  });
}
