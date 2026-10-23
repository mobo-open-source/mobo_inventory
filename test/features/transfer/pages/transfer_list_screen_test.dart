import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/transfer/models/transfer_model.dart';
import 'package:mobo_inv_app/features/transfer/pages/transfer_list_screen.dart';
import 'package:mobo_inv_app/features/transfer/providers/transfer_provider.dart';
import 'package:mobo_inv_app/features/transfer/widgets/transfer_list_tile.dart';
import 'package:mobo_inv_app/shared/widgets/search/mobo_search_filter_bar.dart';
import 'package:mobo_inv_app/shared/widgets/toggles/view_mode_toggle.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fake_access_rights.dart';
import '../../../shared/widgets/layout/landscape_test_helpers.dart';

/// A [TransferProvider] that serves fixed data and never hits the network.
class _FakeTransferProvider extends TransferProvider {
  _FakeTransferProvider({
    this.items = const [],
    this.groups = const {},
    this.groupBy,
  });

  final List<InternalTransfer> items;
  Map<String, int> groups;
  final String? groupBy;
  int refreshCalls = 0;

  /// How often the screen asked for the groups to be summarised afresh.
  int groupSummaryCalls = 0;

  /// Changes the groups the way a new search does, and tells the screen.
  void setGroups(Map<String, int> value) {
    groups = value;
    notifyListeners();
  }

  /// Every `searchQuery` the screen searched for, in order.
  final List<String?> searches = [];
  String query = '';

  /// Stands in for the provider applying [value] as its search, whether
  /// the screen asked for it or something else (e.g. the dashboard) did.
  void applyQuery(String value) {
    query = value;
    notifyListeners();
  }

  @override
  String get searchQuery => query;

  @override
  bool get isLoading => false;
  @override
  bool get hasLoadedOnce => true;
  @override
  String? get error => null;
  @override
  List<InternalTransfer> get transfers => items;
  @override
  int get totalCount => items.length;
  @override
  String? get selectedGroupBy => groupBy;
  @override
  bool get isGrouped => groupBy != null;
  @override
  Map<String, int> get groupSummary => groups;
  @override
  Map<String, List<InternalTransfer>> get loadedGroups => const {};
  @override
  bool get canGoToNextPage => false;
  @override
  bool get canGoToPreviousPage => false;

  @override
  Future<void> fetchTransfers({
    String? searchQuery,
    List<String>? states,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    bool updateFilters = true,
  }) async {
    if (forceRefresh) refreshCalls++;
    if (searchQuery != null) {
      searches.add(searchQuery);
      // Like the real provider, which applies the search it is given.
      query = searchQuery;
    }
  }

  @override
  Future<void> fetchGroupSummary() async => groupSummaryCalls++;

  @override
  Future<void> loadGroupTransfers(String groupKey) async {}
}

List<InternalTransfer> _transfers(int n) => [
  for (var i = 0; i < n; i++)
    InternalTransfer(
      id: i,
      name: 'WH/INT/${i.toString().padLeft(5, '0')}',
      // Always set by Odoo; TransferListTile relies on it.
      scheduledDate: '2026-10-12 09:00:00',
    ),
];

const _groups = {'Draft': 3, 'Waiting': 2, 'Ready': 4, 'Done': 7};

// The real provider also fills `transfers` while grouped; the screen shows its
// empty state otherwise.
_FakeTransferProvider _grouped() => _FakeTransferProvider(
  items: _transfers(16),
  groups: _groups,
  groupBy: 'state',
);

Widget _app(TransferProvider provider, {Set<String> denied = const {}}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TransferProvider>.value(value: provider),
      ChangeNotifierProvider<AccessRightsService>(
        create: (_) => fakeAccessRights(denied: denied),
      ),
    ],
    child: const MaterialApp(home: FakeShell(child: TransferListScreen())),
  );
}

/// Lets the access answers arrive, the screen rebuild and the Scaffold's
/// FAB transition finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

/// Finds [finder] only inside the vertical list (not the pinned header).
Finder _inList(Finder finder) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ),
  matching: finder,
);

void main() {
  group('landscape, grouped (issue 7)', () {
    testWidgets('groups get the height; summary row scrolls with the list', (
      tester,
    ) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_app(_grouped()));
      await tester.pump();

      final body = tabBodyRect(tester);
      expect(find.byType(NestedScrollView), findsOneWidget);
      // "4 groups / Expand All" is the list's first item, not pinned above.
      expect(_inList(find.text('4 groups')), findsOneWidget);
      expect(_inList(find.text('Expand All')), findsOneWidget);
      // Before any scrolling, the first group's title is already on screen.
      expect(tester.getRect(find.text('Draft')).bottom, lessThan(body.bottom));

      // One swipe hides the search bar and chips; the groups fill the body.
      await tester.drag(find.text('Draft'), const Offset(0, -150));
      await tester.pumpAndSettle();
      final draft = tester.getRect(find.text('Draft'));
      expect(draft.top, greaterThanOrEqualTo(body.top));
      expect(draft.bottom, lessThan(body.bottom));
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('last group scrolls clear of the FAB', (tester) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_app(_grouped()));
      await tester.pump();

      await tester.drag(find.text('Draft'), const Offset(0, -1000));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byType(FloatingActionButton));
      // The group card (its §12 shell carries the 8px bottom margin).
      final lastGroup = tester.getRect(
        find.ancestor(
          of: find.text('Done'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container && w.margin == const EdgeInsets.only(bottom: 8),
          ),
        ),
      );
      expect(lastGroup.bottom, lessThanOrEqualTo(fab.top));
    });

    testWidgets('Expand All works from inside the list', (tester) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_app(_grouped()));
      await tester.pump();

      await tester.drag(find.text('Draft'), const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Draft'), const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse All'), findsOneWidget);
      expect(find.text('Expand All'), findsNothing);
    });

    testWidgets('pull to refresh still works', (tester) async {
      setLandscapePhone(tester);
      final provider = _grouped();
      await tester.pumpWidget(_app(provider));
      await tester.pump();

      await tester.fling(find.text('4 groups'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(provider.refreshCalls, 1);
    });
  });

  testWidgets('landscape flat list: last row scrolls clear of the FAB', (
    tester,
  ) async {
    setLandscapePhone(tester);
    await tester.pumpWidget(_app(_FakeTransferProvider(items: _transfers(8))));
    await tester.pump();

    expect(find.byType(NestedScrollView), findsOneWidget);
    await tester.drag(find.text('WH/INT/00000'), const Offset(0, -3000));
    await tester.pumpAndSettle();

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final lastRow = tester.getRect(find.text('WH/INT/00007'));
    expect(lastRow.bottom, lessThanOrEqualTo(fab.top));
  });

  testWidgets('portrait keeps the summary row pinned above the list', (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(_app(_grouped()));
    await tester.pump();

    expect(find.byType(NestedScrollView), findsNothing);
    expect(find.text('4 groups'), findsOneWidget);
    expect(_inList(find.text('4 groups')), findsNothing);
  });

  group('access rights', () {
    testWidgets('the create FAB shows with create rights', (tester) async {
      await tester.pumpWidget(
        _app(_FakeTransferProvider(items: _transfers(3))),
      );
      await _settle(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    for (final denied in ['stock.picking|create', 'stock.move|create']) {
      testWidgets('the create FAB is hidden without $denied', (tester) async {
        await tester.pumpWidget(
          _app(_FakeTransferProvider(items: _transfers(3)), denied: {denied}),
        );
        await _settle(tester);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }

    for (final denied in [
      'stock.picking|write',
      'stock.move|unlink',
      'stock.move|create',
    ]) {
      testWidgets('long-press edit says no without $denied', (tester) async {
        await tester.pumpWidget(
          _app(_FakeTransferProvider(items: _transfers(3)), denied: {denied}),
        );
        await _settle(tester);

        await tester.longPress(find.text('WH/INT/00000'));
        await tester.pump();
        expect(
          find.text("You don't have permission to edit transfers"),
          findsOneWidget,
        );
        // Still on the list: the form was not opened.
        expect(find.byType(TransferListScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 5)); // let the snackbar go
      });
    }
  });

  group('search field follows the provider', () {
    testWidgets('an outside change of the search shows in the field', (
      tester,
    ) async {
      final provider = _FakeTransferProvider(items: _transfers(3));
      await tester.pumpWidget(_app(provider));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'WH/INT');
      await tester.pump(const Duration(milliseconds: 600));
      expect(provider.searches, ['WH/INT']);
      provider.applyQuery('WH/INT'); // the provider applies it
      await tester.pump();
      expect(find.text('WH/INT'), findsOneWidget);

      // E.g. the dashboard's Internal Transfers card clears the search.
      provider.applyQuery('');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      // Updating the field is not a new search.
      await tester.pump(const Duration(milliseconds: 600));
      expect(provider.searches, ['WH/INT']);
    });

    testWidgets('typing on is not undone when an earlier search lands', (
      tester,
    ) async {
      final provider = _FakeTransferProvider(items: _transfers(3));
      await tester.pumpWidget(_app(provider));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'WH');
      await tester.pump(const Duration(milliseconds: 600)); // 'WH' sent
      await tester.enterText(find.byType(TextField), 'WH/IN'); // still typing
      provider.applyQuery('WH'); // the earlier search lands meanwhile
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'WH/IN');
      await tester.pump(const Duration(milliseconds: 600));
      expect(provider.searches, ['WH', 'WH/IN']);
    });

    testWidgets('pull to refresh keeps the search applied', (tester) async {
      final provider = _FakeTransferProvider(items: _transfers(3));
      await tester.pumpWidget(_app(provider));
      await _settle(tester);

      await tester.fling(find.text('WH/INT/00000'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(provider.refreshCalls, 1);
      // Refreshing passes no new query, so the applied one stays.
      expect(provider.searches, isEmpty);
    });
  });

  group('search while grouped', () {
    // The "x" of the search field.
    final clearButton = find.descendant(
      of: find.byType(MoboSearchFilterBar),
      matching: find.byType(IconButton),
    );

    Future<_FakeTransferProvider> open(
      WidgetTester tester,
      _FakeTransferProvider provider,
    ) async {
      await tester.pumpWidget(_app(provider));
      await _settle(tester);
      // Not the groups the screen loads when it opens.
      provider.groupSummaryCalls = 0;
      return provider;
    }

    testWidgets('a search summarises the groups afresh', (tester) async {
      final provider = await open(tester, _grouped());

      await tester.enterText(find.byType(TextField), 'WH');
      await tester.pump(const Duration(milliseconds: 600));

      expect(provider.searches, ['WH']);
      // The groups, not only the flat list, are searched: they are what a
      // grouped screen shows.
      expect(provider.groupSummaryCalls, 1);
    });

    testWidgets('clearing the search with the x brings every group back', (
      tester,
    ) async {
      final provider = await open(tester, _grouped());

      await tester.enterText(find.byType(TextField), 'WH');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(clearButton);
      await tester.pump(const Duration(milliseconds: 600));

      expect(provider.searches, ['WH', '']);
      expect(provider.groupSummaryCalls, 2);
    });

    testWidgets('a flat list has no groups to summarise', (tester) async {
      final provider = await open(tester, _FakeTransferProvider(items: _transfers(3)));

      await tester.enterText(find.byType(TextField), 'WH');
      await tester.pump(const Duration(milliseconds: 600));

      expect(provider.searches, ['WH']);
      expect(provider.groupSummaryCalls, 0);
    });

    testWidgets('moving the cursor is not a new search', (tester) async {
      final provider = await open(tester, _grouped());

      await tester.enterText(find.byType(TextField), 'WH');
      await tester.pump(const Duration(milliseconds: 600));
      // Tapping into the field notifies its listeners without a new text.
      tester.widget<TextField>(find.byType(TextField)).controller!.selection =
          const TextSelection.collapsed(offset: 0);
      await tester.pump(const Duration(milliseconds: 600));

      expect(provider.searches, ['WH']);
      expect(provider.groupSummaryCalls, 1);
    });

    testWidgets('a group the search dropped comes back closed', (tester) async {
      final provider = await open(tester, _grouped());

      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNWidgets(4));

      // A search leaves only 'Done', then it is cleared again.
      provider.setGroups({'Done': 7});
      await tester.pump();
      provider.setGroups(_groups);
      await tester.pump();

      // Only 'Done' stayed open throughout; the others come back closed (not
      // open and empty), so Expand All is offered for them again.
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('Expand All'), findsOneWidget);
    });
  });

  testWidgets('list only: no list/kanban toggle', (tester) async {
    await tester.pumpWidget(_app(_FakeTransferProvider(items: _transfers(3))));
    await _settle(tester);

    expect(find.byType(ViewModeToggle), findsNothing);
    expect(find.byType(TransferListTile), findsNWidgets(3));
  });

  group('pager', () {
    testWidgets("a grouped list's pager counts groups, as Odoo's does", (
      tester,
    ) async {
      await tester.pumpWidget(_app(_grouped()));
      await _settle(tester);

      expect(find.text('1-4/4'), findsOneWidget);
    });
  });
}
