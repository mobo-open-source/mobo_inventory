import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/kanban/mobo_kanban_board.dart';

Widget _board({
  required Map<String, int> groups,
  required Map<String, List<String>> loaded,
  required Future<void> Function(String) onLoad,
  Future<void> Function(String)? onLoadMore,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoboKanbanBoard<String>(
        groups: groups,
        loadedGroups: loaded,
        onLoadGroup: onLoad,
        onLoadMore: onLoadMore,
        itemBuilder: (_, item) => SizedBox(height: 40, child: Text(item)),
      ),
    ),
  );
}

void main() {
  testWidgets('a column per group, side by side, headed by its count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _board(
        groups: const {'Draft': 2, 'Ready': 5},
        loaded: const {
          'Draft': ['WH/INT/1', 'WH/INT/2'],
          'Ready': ['WH/INT/3'],
        },
        onLoad: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    final board = find.byKey(const ValueKey('kanbanBoard'));
    expect(tester.widget<ListView>(board).scrollDirection, Axis.horizontal);
    final draft = find.byKey(const ValueKey('kanbanColumn_Draft'));
    final ready = find.byKey(const ValueKey('kanbanColumn_Ready'));
    expect(
      tester.getTopLeft(ready).dx,
      greaterThan(tester.getTopRight(draft).dx),
    );
    // The server's count, not the cards loaded so far, in brackets as Odoo's
    // column headers show it.
    expect(find.descendant(of: ready, matching: find.text('(5)')), findsOne);
    expect(find.descendant(of: ready, matching: find.text('Ready')), findsOne);
    expect(
      find.descendant(of: draft, matching: find.text('WH/INT/2')),
      findsOne,
    );
  });

  testWidgets('a column loads its group once, and offers Retry if it failed', (
    tester,
  ) async {
    final asked = <String>[];
    await tester.pumpWidget(
      _board(
        groups: const {'Draft': 2},
        loaded: const {},
        onLoad: (key) async => asked.add(key),
      ),
    );
    await tester.pumpAndSettle();

    expect(asked, ['Draft']);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(asked, ['Draft', 'Draft']);
  });

  testWidgets('"Load more" while a column shows fewer cards than its count', (
    tester,
  ) async {
    final more = <String>[];
    await tester.pumpWidget(
      _board(
        groups: const {'Done': 3, 'Ready': 1},
        loaded: const {
          'Done': ['A'],
          'Ready': ['B'],
        },
        onLoad: (_) async {},
        onLoadMore: (key) async => more.add(key),
      ),
    );
    await tester.pumpAndSettle();

    // Only Done has more to show.
    expect(find.text('Load more (2)'), findsOneWidget);
    await tester.tap(find.text('Load more (2)'));
    await tester.pumpAndSettle();
    expect(more, ['Done']);
  });
}
