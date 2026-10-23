import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/session_service.dart';
import 'package:mobo_inv_app/features/picking/models/picking_model.dart';
import 'package:mobo_inv_app/features/picking/pages/picking_list_screen.dart';
import 'package:mobo_inv_app/features/picking/providers/picking_provider.dart';
import 'package:mobo_inv_app/features/picking/services/picking_service.dart';
import 'package:mobo_inv_app/features/picking/widgets/picking_list_tile.dart';
import 'package:mobo_inv_app/shared/widgets/search/mobo_search_filter_bar.dart';
import 'package:provider/provider.dart';

/// A [PickingProvider] that serves fixed data and never hits the network.
class _FakePickingProvider extends PickingProvider {
  _FakePickingProvider({required this.fakeItems, this.fakeGroups, this.groupBy})
    : super(
        pickingTypeCode: 'outgoing',
        initialStates: PickingService.toProcessStates,
      );

  final List<Picking> fakeItems;
  final Map<String, int>? fakeGroups;
  final String? groupBy;
  final Map<String, List<Picking>> _loaded = {};
  int refreshCalls = 0;

  @override
  List<Picking> get items => fakeItems;
  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedOnce => true;
  @override
  String? get error => null;
  @override
  int get totalCount => fakeItems.length;
  @override
  String? get selectedGroupBy => groupBy;
  @override
  Map<String, int> get groupSummary => fakeGroups ?? const {};
  @override
  Map<String, List<Picking>> get loadedGroups => _loaded;
  @override
  bool get canGoToNextPage => false;
  @override
  bool get canGoToPreviousPage => false;
  @override
  String getPaginationText() => '1-${fakeItems.length}/${fakeItems.length}';

  @override
  Future<void> fetchPickings({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) refreshCalls++;
  }

  @override
  Future<void> fetchGroupSummary() async {}

  @override
  Future<void> loadGroupPickings(String groupKey) async {
    _loaded[groupKey] = fakeItems;
    notifyListeners();
  }
}

List<Picking> _pickings(int n) => [
  for (var i = 0; i < n; i++)
    Picking(
      id: i,
      name: 'WH/OUT/0000$i',
      state: 'assigned',
      pickingTypeCode: 'outgoing',
      pickingTypeName: 'Delivery Orders',
      scheduledDate: '2026-10-12 10:00:00',
    ),
];

_FakePickingProvider _grouped() => _FakePickingProvider(
  fakeItems: _pickings(9),
  fakeGroups: const {'Urgent': 9},
  groupBy: 'priority',
);

/// 800×360 logical px with a 24px status bar: a phone in landscape.
void _landscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1080);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72);
  addTearDown(tester.view.reset);
}

/// The same phone in portrait.
void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72);
  addTearDown(tester.view.reset);
}

Widget _app(PickingProvider provider) => MultiProvider(
  providers: [
    ChangeNotifierProvider<PickingProvider>.value(value: provider),
    ChangeNotifierProvider<SessionService>.value(
      value: SessionService.instance,
    ),
  ],
  child: const MaterialApp(
    home: PickingListScreen(
      title: 'Delivery Orders',
      pickingTypeCode: 'outgoing',
    ),
  ),
);

/// Inside the list itself (not the header above it).
Finder _inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

double _appBarBottom(WidgetTester tester) =>
    tester.getBottomLeft(find.byType(AppBar)).dy;

/// The search bar has scrolled up behind the app bar — or so far that the
/// list no longer builds it.
void _expectHeaderScrolledAway(WidgetTester tester) {
  final search = find.byType(MoboSearchFilterBar);
  if (search.evaluate().isEmpty) return;
  expect(
    tester.getRect(search).bottom,
    lessThanOrEqualTo(_appBarBottom(tester)),
  );
}

void main() {
  group('landscape', () {
    testWidgets('grouped: the groups row is the list\'s first item and the '
        'header scrolls away', (tester) async {
      _landscape(tester);
      await tester.pumpWidget(_app(_grouped()));
      await tester.pump();

      expect(find.byType(NestedScrollView), findsOneWidget);
      expect(_inList(find.text('1 group')), findsOneWidget);
      expect(_inList(find.text('Expand All')), findsOneWidget);

      await tester.drag(find.text('Urgent'), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Search bar and filter row are gone above the app bar's bottom edge;
      // the group fills the room they left.
      _expectHeaderScrolledAway(tester);
      expect(
        tester.getRect(find.text('Urgent')).top,
        greaterThanOrEqualTo(_appBarBottom(tester)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('grouped: Expand All from inside the list shows the pickings', (
      tester,
    ) async {
      _landscape(tester);
      await tester.pumpWidget(_app(_grouped()));
      await tester.pump();

      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse All'), findsOneWidget);

      await tester.drag(find.text('Urgent'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('WH/OUT/00000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grouped: pull to refresh still works', (tester) async {
      _landscape(tester);
      final provider = _grouped();
      await tester.pumpWidget(_app(provider));
      await tester.pump();

      await tester.fling(find.text('1 group'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(provider.refreshCalls, 1);
    });

    testWidgets('flat list: the header scrolls away with the rows', (
      tester,
    ) async {
      _landscape(tester);
      await tester.pumpWidget(
        _app(_FakePickingProvider(fakeItems: _pickings(12))),
      );
      await tester.pump();

      expect(find.byType(NestedScrollView), findsOneWidget);
      await tester.drag(find.text('WH/OUT/00000'), const Offset(0, -300));
      await tester.pumpAndSettle();

      _expectHeaderScrolledAway(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('portrait keeps the header and the groups row pinned', (
    tester,
  ) async {
    _portrait(tester);
    await tester.pumpWidget(_app(_grouped()));
    await tester.pump();

    expect(find.byType(NestedScrollView), findsNothing);
    expect(find.text('1 group'), findsOneWidget);
    expect(_inList(find.text('1 group')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records are shown, not opened: no tap on a row', (tester) async {
    await tester.pumpWidget(
      _app(_FakePickingProvider(fakeItems: _pickings(3))),
    );
    await tester.pump();

    final tiles = tester.widgetList<PickingListTile>(
      find.byType(PickingListTile),
    );
    expect(tiles, hasLength(3));
    expect(tiles.every((tile) => tile.onTap == null), isTrue);

    // Grouped rows likewise.
    await tester.pumpWidget(_app(_grouped()));
    await tester.pump();
    await tester.tap(find.text('Expand All'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<PickingListTile>(find.byType(PickingListTile))
          .every((tile) => tile.onTap == null),
      isTrue,
    );
  });
}
