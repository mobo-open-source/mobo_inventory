import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/adjustment/models/inventory_adjustment_model.dart';
import 'package:mobo_inv_app/features/inventory/widgets/adjustment_picker_sheet.dart';

final _quants = [
  for (var i = 1; i <= 12; i++)
    InventoryAdjustment(
      id: i,
      location: 'WH/Stock/Shelf $i',
      lotSerial: i.isEven ? 'LOT-$i' : null,
      onHandQuantity: i.toDouble(),
      countedQuantity: 0,
      difference: 0,
    ),
];

Future<ValueNotifier<InventoryAdjustment?>> _open(
  WidgetTester tester,
  Size size, {
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    left: padding.left,
    top: padding.top,
    right: padding.right,
    bottom: padding.bottom,
  );
  addTearDown(tester.view.reset);

  final picked = ValueNotifier<InventoryAdjustment?>(null);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                picked.value = await AdjustmentPickerSheet.show(
                  context,
                  adjustments: _quants,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
}

Rect _sheetRect(WidgetTester tester) =>
    tester.getRect(find.byType(AdjustmentPickerSheet));

void main() {
  testWidgets('landscape phone: fits, capped at 640 wide, list scrolls', (
    tester,
  ) async {
    // 800×360 with a notch on the left and a gesture bar at the bottom.
    final picked = await _open(
      tester,
      const Size(800, 360),
      padding: const EdgeInsets.only(left: 32, top: 24, bottom: 16),
    );

    expect(tester.takeException(), isNull);
    final sheet = _sheetRect(tester);
    expect(sheet.width, lessThanOrEqualTo(640));
    expect(sheet.bottom, lessThanOrEqualTo(360));
    // Clear of the status bar (useSafeArea).
    expect(sheet.top, greaterThanOrEqualTo(24));
    expect(find.text('Select Location / Lot'), findsOneWidget);

    // The last quant is reachable by scrolling, and picking it pops it.
    final list = find.byKey(const ValueKey('adjustmentPickerList'));
    await tester.drag(list, const Offset(0, -2000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.text('WH/Stock/Shelf 12'));
    expect(last.bottom, lessThanOrEqualTo(_sheetRect(tester).bottom));
    // The title stayed pinned above the scrolled list.
    expect(find.text('Select Location / Lot'), findsOneWidget);
    await tester.tap(find.text('WH/Stock/Shelf 12'));
    await tester.pumpAndSettle();
    expect(picked.value?.id, 12);
  });

  testWidgets('portrait phone: at most 60% of the screen tall', (tester) async {
    await _open(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(_sheetRect(tester).height, lessThanOrEqualTo(844 * 0.6 + 0.5));
    expect(find.text('Lot: LOT-2  ·  On hand: 2.00'), findsOneWidget);
  });

  testWidgets('very short screen: the whole sheet scrolls, no overflow', (
    tester,
  ) async {
    await _open(tester, const Size(640, 200));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('adjustmentPickerList')), findsNothing);
    expect(_sheetRect(tester).bottom, lessThanOrEqualTo(200));
  });
}
