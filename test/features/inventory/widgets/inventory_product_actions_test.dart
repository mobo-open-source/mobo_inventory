import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/inventory/widgets/inventory_product_kanban_card.dart';
import 'package:mobo_inv_app/features/inventory/widgets/inventory_product_list_tile.dart';

Widget _tile({
  required double onHand,
  VoidCallback? onEdit,
  VoidCallback? onLocate,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: InventoryProductListTile(
          id: '1',
          name: 'Cable',
          defaultCode: 'CAB-1',
          qtyOnHand: onHand,
          qtyIncoming: 0,
          qtyOutgoing: 0,
          qtyAvailable: onHand,
          freeQty: onHand,
          avgCost: 1,
          totalValue: onHand,
          uomName: 'Units',
          isDark: false,
          onEdit: onEdit,
          onLocate: onLocate,
          onTap: onTap,
        ),
      ),
    ),
  );
}

Widget _card({
  required double onHand,
  VoidCallback? onEdit,
  VoidCallback? onLocate,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: InventoryProductKanbanCard(
          name: 'Cable',
          defaultCode: 'CAB-1',
          qtyOnHand: onHand,
          freeQty: onHand,
          listPrice: 4,
          uomName: 'Units',
          isDark: false,
          compact: true,
          onEdit: onEdit,
          onLocate: onLocate,
          onTap: onTap,
        ),
      ),
    ),
  );
}

void main() {
  group('list tile', () {
    testWidgets('nothing on hand: "Edit" is a button of its own, one tap', (
      tester,
    ) async {
      var edited = 0;
      var opened = 0;
      await tester.pumpWidget(
        _tile(
          onHand: 0,
          onEdit: () => edited++,
          onLocate: () {},
          onTap: () => opened++,
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();

      expect(edited, 1);
      // The tap was the button's, not the row's.
      expect(opened, 0);
    });

    testWidgets('stock on hand: "Locate" and "Edit" stay in the menu', (
      tester,
    ) async {
      var edited = 0;
      await tester.pumpWidget(
        _tile(onHand: 5, onEdit: () => edited++, onLocate: () {}),
      );

      expect(find.byTooltip('Edit'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Locate'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(edited, 1);
    });

    testWidgets('no right to edit and nothing to locate: no action at all', (
      tester,
    ) async {
      await tester.pumpWidget(_tile(onHand: 0, onLocate: () {}));

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
    });
  });

  group('kanban card', () {
    testWidgets('nothing on hand: "Edit" is a button of its own, one tap', (
      tester,
    ) async {
      var edited = 0;
      await tester.pumpWidget(
        _card(onHand: 0, onEdit: () => edited++, onLocate: () {}),
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();
      expect(edited, 1);
    });

    testWidgets('stock on hand: "Locate" and "Edit" stay in the menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(onHand: 5, onEdit: () {}, onLocate: () {}),
      );

      expect(find.byTooltip('Edit'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Locate'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });
}
