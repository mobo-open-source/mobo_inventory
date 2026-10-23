import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/move_history/models/move_history_item.dart';
import 'package:mobo_inv_app/features/move_history/pages/move_history_screen.dart';
import 'package:mobo_inv_app/features/move_history/providers/move_history_provider.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/layout/landscape_test_helpers.dart';

/// A [MoveHistoryProvider] that serves fixed data and never hits the network.
class _FakeMoveHistoryProvider extends MoveHistoryProvider {
  _FakeMoveHistoryProvider({required this.fakeItems, this.groupBy});

  final List<MoveHistoryItem> fakeItems;
  final String? groupBy;
  int refreshCalls = 0;

  @override
  List<MoveHistoryItem> get items => fakeItems;
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
  bool get canGoToNextPage => false;
  @override
  bool get canGoToPreviousPage => false;
  @override
  String getPaginationText() => '1-${fakeItems.length}/${fakeItems.length}';

  /// The server's counts per group, in its order.
  @override
  Map<String, int> get groupSummary => groupBy == null
      ? const {}
      : const {
          'Available': 3,
          'Cancelled': 3,
          'Done': 3,
          'Waiting Availability': 3,
        };
  @override
  Map<String, List<MoveHistoryItem>> get loadedGroups => const {};
  @override
  Future<void> loadGroupItems(String groupKey) async {}

  @override
  Future<void> fetchHistory({
    String? searchQuery,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    List<String>? pickingTypeCodes,
    bool? activeOnly,
    bool? inventoryOnly,
    String? groupBy,
    bool updateFilters = false,
    bool force = false,
  }) async {}

  @override
  Future<void> refresh() async => refreshCalls++;
}

const _states = ['done', 'cancel', 'assigned', 'confirmed'];

List<MoveHistoryItem> _moves(int n) => [
  for (var i = 0; i < n; i++)
    MoveHistoryItem(
      id: i,
      product: 'Product $i',
      reference: 'WH/OUT/$i',
      quantity: 1,
      status: _states[i % _states.length],
      fromLocation: 'WH/Stock',
      toLocation: 'Partners/Customers',
    ),
];

Widget _app(MoveHistoryProvider provider) {
  return ChangeNotifierProvider<MoveHistoryProvider>.value(
    value: provider,
    child: const MaterialApp(home: FakeShell(child: MoveHistoryScreen())),
  );
}

Finder _inList(Finder finder) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ),
  matching: finder,
);

void main() {
  group('landscape, grouped (History tab)', () {
    testWidgets('header scrolls away; groups get the height', (tester) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(
        _app(_FakeMoveHistoryProvider(fakeItems: _moves(12), groupBy: 'state')),
      );
      await tester.pump();

      final body = tabBodyRect(tester);
      expect(find.byType(NestedScrollView), findsOneWidget);
      expect(_inList(find.text('4 groups')), findsOneWidget);

      // Scroll by exactly the header's height: the summary row reaches the
      // top of the tab body and the groups follow it.
      final summaryTop = tester.getTopLeft(find.text('4 groups')).dy;
      await tester.drag(
        find.text('4 groups'),
        Offset(0, -(summaryTop - body.top)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing); // search bar scrolled off

      // Groups come in the server's order: "Available" first.
      final first = tester.getRect(find.text('Available'));
      expect(first.top, greaterThanOrEqualTo(body.top));
      expect(first.bottom, lessThan(body.bottom));
    });

    testWidgets('pull to refresh still works', (tester) async {
      setLandscapePhone(tester);
      final provider = _FakeMoveHistoryProvider(
        fakeItems: _moves(12),
        groupBy: 'state',
      );
      await tester.pumpWidget(_app(provider));
      await tester.pump();

      await tester.fling(find.text('4 groups'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(provider.refreshCalls, 1);
    });
  });

  testWidgets('landscape flat list scrolls under a collapsing header', (
    tester,
  ) async {
    setLandscapePhone(tester);
    await tester.pumpWidget(
      _app(_FakeMoveHistoryProvider(fakeItems: _moves(12))),
    );
    await tester.pump();

    final body = tabBodyRect(tester);
    await tester.drag(find.text('Product 0'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing); // search bar scrolled off
    expect(
      tester.getTopLeft(find.byType(NestedScrollView)).dy,
      moreOrLessEquals(body.top),
    );
  });

  testWidgets("a grouped list's pager counts groups, as Odoo's does", (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(
      _app(_FakeMoveHistoryProvider(fakeItems: _moves(12), groupBy: 'state')),
    );
    await tester.pump();

    expect(find.text('1-4/4'), findsOneWidget);
    // Not the move lines' pager.
    expect(find.text('1-12/12'), findsNothing);
  });

  testWidgets('portrait keeps the summary row pinned above the list', (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(
      _app(_FakeMoveHistoryProvider(fakeItems: _moves(12), groupBy: 'state')),
    );
    await tester.pump();

    expect(find.byType(NestedScrollView), findsNothing);
    expect(find.text('4 groups'), findsOneWidget);
    expect(_inList(find.text('4 groups')), findsNothing);
  });
}
