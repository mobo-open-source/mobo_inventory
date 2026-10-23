import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/core/services/session_service.dart';
import 'package:mobo_inv_app/features/company/providers/company_provider.dart';
import 'package:mobo_inv_app/features/profile/providers/profile_provider.dart';
import 'package:mobo_inv_app/features/replenishment/models/replenishment_orderpoint.dart';
import 'package:mobo_inv_app/features/replenishment/pages/replenishment_list_screen.dart';
import 'package:mobo_inv_app/features/replenishment/providers/replenishment_provider.dart';
import 'package:mobo_inv_app/features/replenishment/services/replenishment_service.dart';
import 'package:mobo_inv_app/features/replenishment/widgets/edit_orderpoint_values_sheet.dart';
import 'package:mobo_inv_app/features/replenishment/widgets/snooze_bottom_sheet.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fake_access_rights.dart';
import '../../../shared/widgets/layout/landscape_test_helpers.dart';

/// A [ReplenishmentProvider] that serves fixed data and never hits the
/// network.
class _FakeReplenishmentProvider extends ReplenishmentProvider {
  _FakeReplenishmentProvider({
    this.fakeItems = const [],
    this.fakeGroups = const [],
    this.groupBy,
  });

  final List<ReplenishmentOrderpoint> fakeItems;
  final List<ReplenishmentGroup> fakeGroups;
  final String? groupBy;
  int refreshCalls = 0;

  @override
  List<ReplenishmentOrderpoint> get items => fakeItems;
  @override
  List<ReplenishmentGroup> get groups => fakeGroups;
  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedOnce => true;
  @override
  String? get error => null;
  @override
  int get totalCount => groupBy == null
      ? fakeItems.length
      : fakeGroups.fold(0, (a, g) => a + g.count);
  @override
  String? get selectedGroupBy => groupBy;
  @override
  bool get isGrouped => groupBy != null;
  @override
  bool get isEmpty => isGrouped ? fakeGroups.isEmpty : fakeItems.isEmpty;
  @override
  bool get canGoToNextPage => false;
  @override
  bool get canGoToPreviousPage => false;
  @override
  String getPaginationText() => '1-${fakeItems.length}/${fakeItems.length}';
  @override
  List<ReplenishmentOrderpoint>? itemsForGroup(String key) => fakeItems;
  @override
  bool isGroupLoading(String key) => false;
  @override
  bool isGroupFailed(String key) => false;

  @override
  Future<void> fetch({
    String? searchQuery,
    bool? notSnoozed,
    bool? toReorder,
    String? trigger,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) refreshCalls++;
  }

  @override
  Future<void> loadGroup(String key, {bool force = false}) async {}
}

List<ReplenishmentOrderpoint> _rules(int n) => [
  for (var i = 0; i < n; i++)
    ReplenishmentOrderpoint(
      id: i,
      productId: i,
      productName: 'Product $i',
      locationId: 1,
      locationName: 'WH/Stock',
      onHand: 0,
      forecast: 0,
      minQty: 5,
      maxQty: 10,
      toOrder: 10,
      trigger: 'manual',
      snoozed: false,
    ),
];

// As in the tester's screenshot: one warehouse group of nine rules.
_FakeReplenishmentProvider _grouped() => _FakeReplenishmentProvider(
  fakeItems: _rules(9),
  fakeGroups: const [
    ReplenishmentGroup(key: '1', label: 'Main Warehouse', value: 1, count: 9),
  ],
  groupBy: 'warehouse_id',
);

Widget _app(ReplenishmentProvider provider, {Set<String> denied = const {}}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ReplenishmentProvider>.value(value: provider),
      ChangeNotifierProvider<AccessRightsService>(
        create: (_) => fakeAccessRights(denied: denied),
      ),
      ChangeNotifierProvider<CompanyProvider>(create: (_) => CompanyProvider()),
      ChangeNotifierProvider<SessionService>.value(
        value: SessionService.instance,
      ),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
    ],
    // The shell shows no AppBar on this tab; the screen draws its own.
    child: const MaterialApp(
      home: FakeShell(showAppBar: false, child: ReplenishmentListScreen()),
    ),
  );
}

Finder _inList(Finder finder) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ),
  matching: finder,
);

void main() {
  group('landscape, grouped (issue 8)', () {
    testWidgets(
      'title, search and chips scroll away; the group gets the room',
      (tester) async {
        setLandscapePhone(tester);
        await tester.pumpWidget(_app(_grouped()));
        await tester.pump();

        final body = tabBodyRect(tester);
        expect(find.byType(NestedScrollView), findsOneWidget);
        // The title row is part of the scrolling header, not a pinned AppBar.
        expect(
          find.descendant(
            of: find.byType(NestedScrollView),
            matching: find.text('Replenishment'),
          ),
          findsOneWidget,
        );
        // It sits below the status bar, not under it.
        expect(
          tester.getTopLeft(find.byType(NestedScrollView)).dy,
          moreOrLessEquals(body.top),
        );
        expect(_inList(find.text('1 groups · 9 rules')), findsOneWidget);
        // Same compact height as the shell's app bar on the other tabs.
        expect(tester.getSize(find.byType(AppBar)).height, 48);

        await tester.drag(find.text('Main Warehouse'), const Offset(0, -200));
        await tester.pumpAndSettle();

        final group = tester.getRect(find.text('Main Warehouse'));
        expect(group.top, greaterThanOrEqualTo(body.top));
        expect(group.bottom, lessThan(body.bottom));
        expect(find.text('Replenishment'), findsNothing); // scrolled off
      },
    );

    testWidgets('Expand All from inside the list shows the rules', (
      tester,
    ) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_app(_grouped()));
      await tester.pump();

      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse All'), findsOneWidget);

      await tester.drag(find.text('Main Warehouse'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('Product 0'), findsOneWidget);
      final body = tabBodyRect(tester);
      expect(
        tester.getRect(find.text('Product 0')).bottom,
        lessThan(body.bottom),
      );
    });

    testWidgets('pull to refresh still works', (tester) async {
      setLandscapePhone(tester);
      final provider = _grouped();
      await tester.pumpWidget(_app(provider));
      await tester.pump();

      await tester.fling(
        find.text('1 groups · 9 rules'),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(provider.refreshCalls, 1);
    });
  });

  testWidgets('portrait keeps the AppBar and the pinned summary row', (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(_app(_grouped()));
    await tester.pump();

    expect(find.byType(NestedScrollView), findsNothing);
    final scaffold = tester.widget<Scaffold>(
      find
          .ancestor(
            of: find.byType(ReplenishmentListScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.appBar, isNull); // the shell's
    final screenScaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(ReplenishmentListScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(screenScaffold.appBar, isA<AppBar>());
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight + 24);
    expect(find.text('1 groups · 9 rules'), findsOneWidget);
    expect(_inList(find.text('1 groups · 9 rules')), findsNothing);
  });

  group('landscape sheets fit', () {
    Widget launcher(Future<void> Function(BuildContext) open) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    testWidgets('snooze sheet scrolls instead of overflowing', (tester) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(launcher(SnoozeBottomSheet.show));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Below the status bar; the last option is reachable by scrolling.
      expect(
        tester.getTopLeft(find.byType(SnoozeBottomSheet)).dy,
        greaterThanOrEqualTo(24),
      );
      await tester.dragUntilVisible(
        find.text('Custom...'),
        find.byType(SnoozeBottomSheet),
        const Offset(0, -100),
      );
      expect(
        tester.getRect(find.text('Custom...')).bottom,
        lessThanOrEqualTo(360),
      );
    });

    testWidgets('edit values sheet keeps its buttons reachable', (
      tester,
    ) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(
        launcher(
          (context) => EditOrderpointValuesSheet.show(
            context,
            initialMin: 1,
            initialMax: 5,
            initialToOrder: 0,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Save'),
        find.byType(EditOrderpointValuesSheet),
        const Offset(0, -100),
      );
      expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(360));
    });
  });

  group('orderpoint write access', () {
    Future<void> pumpFlat(
      WidgetTester tester, {
      Set<String> denied = const {},
    }) async {
      setPortraitPhone(tester);
      await tester.pumpWidget(
        _app(_FakeReplenishmentProvider(fakeItems: _rules(2)), denied: denied),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    testWidgets('with it, each rule has its actions menu', (tester) async {
      await pumpFlat(tester);
      expect(find.byTooltip('Actions'), findsNWidgets(2));
    });

    testWidgets('without it, the menu and the edit tap are gone', (
      tester,
    ) async {
      await pumpFlat(tester, denied: {'stock.warehouse.orderpoint|write'});
      expect(find.byTooltip('Actions'), findsNothing);

      await tester.tap(find.text('On Hand').first);
      await tester.pumpAndSettle();
      expect(find.byType(EditOrderpointValuesSheet), findsNothing);
    });
  });
}
