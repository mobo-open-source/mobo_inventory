import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/inventory/widgets/create_adjustment_dialog.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_access.dart';

const _locations = <Map<String, dynamic>>[
  {'id': 8, 'name': 'Stock', 'complete_name': 'WH/Stock'},
  {'id': 9, 'name': 'Shelf 1', 'complete_name': 'WH/Stock/Shelf 1'},
];

const _applyKey = ValueKey('adjustmentApplyButton');
const _cancelKey = ValueKey('adjustmentCancelButton');

/// Opens the dialog on a [size] screen, optionally with the keyboard up.
Future<ValueNotifier<CreateAdjustmentResult?>> _open(
  WidgetTester tester,
  Size size, {
  double keyboard = 0,
  AccessRightsService? access,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (keyboard > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }
  addTearDown(tester.view.reset);

  final result = ValueNotifier<CreateAdjustmentResult?>(null);
  final app = MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              result.value = await CreateAdjustmentDialog.show(
                context,
                locations: _locations,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    access == null
        ? app
        : ChangeNotifierProvider<AccessRightsService>.value(
            value: access,
            child: app,
          ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Rect _dialogRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first,
);

void _expectFooterInsideDialog(WidgetTester tester) {
  final dialog = _dialogRect(tester);
  for (final key in [_cancelKey, _applyKey]) {
    final button = tester.getRect(find.byKey(key));
    expect(button.height, 48, reason: '$key height');
    expect(
      dialog.contains(button.topLeft) &&
          dialog.contains(button.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
      reason: '$key $button should sit on the dialog surface $dialog',
    );
  }
}

void _expectSingleLineLabels(WidgetTester tester) {
  for (final label in ['Cancel', 'Create & Apply']) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
    expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    // One 16px line, not two.
    expect(paragraph.size.height, lessThan(30), reason: label);
  }
}

void main() {
  testWidgets('portrait phone: buttons 48 high, labels on one line', (
    tester,
  ) async {
    await _open(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    _expectFooterInsideDialog(tester);
    _expectSingleLineLabels(tester);
  });

  testWidgets('small portrait phone keeps "Create & Apply" on one line', (
    tester,
  ) async {
    await _open(tester, const Size(320, 568));

    expect(tester.takeException(), isNull);
    _expectFooterInsideDialog(tester);
    _expectSingleLineLabels(tester);
  });

  testWidgets('landscape phone: footer stays inside, width capped at 480', (
    tester,
  ) async {
    await _open(tester, const Size(800, 360));

    expect(tester.takeException(), isNull);
    expect(_dialogRect(tester).width, lessThanOrEqualTo(480));
    _expectFooterInsideDialog(tester);
    _expectSingleLineLabels(tester);
  });

  testWidgets('landscape phone with the keyboard up still fits the dialog', (
    tester,
  ) async {
    await _open(tester, const Size(800, 360), keyboard: 180);

    expect(tester.takeException(), isNull);
    final dialog = _dialogRect(tester);
    // The dialog moved up out of the keyboard's way.
    expect(dialog.bottom, lessThanOrEqualTo(360 - 180));
    // Too short to pin title and footer, so the whole dialog scrolls; the
    // footer is reachable and on the dialog surface.
    await tester.ensureVisible(find.byKey(_applyKey));
    await tester.pumpAndSettle();
    _expectFooterInsideDialog(tester);
  });

  testWidgets('Create & Apply returns the location and counted quantity', (
    tester,
  ) async {
    final result = await _open(tester, const Size(360, 640));

    await tester.enterText(
      find.byKey(const ValueKey('countedQuantityField')),
      '12.5',
    );
    await tester.tap(find.byKey(_applyKey));
    await tester.pumpAndSettle();

    expect(find.byType(CreateAdjustmentDialog), findsNothing);
    expect(result.value?.locationId, 8);
    expect(result.value?.countedQuantity, 12.5);
  });

  testWidgets('an empty quantity is flagged instead of applied as zero', (
    tester,
  ) async {
    final result = await _open(tester, const Size(360, 640));

    await tester.tap(find.byKey(_applyKey));
    await tester.pumpAndSettle();

    expect(find.byType(CreateAdjustmentDialog), findsOneWidget);
    expect(find.text('Enter a counted quantity of 0 or more'), findsOneWidget);
    expect(result.value, isNull);
  });

  testWidgets('Cancel closes without a result', (tester) async {
    final result = await _open(tester, const Size(360, 640));

    await tester.tap(find.byKey(_cancelKey));
    await tester.pumpAndSettle();

    expect(find.byType(CreateAdjustmentDialog), findsNothing);
    expect(result.value, isNull);
  });

  testWidgets('without the right to apply, it saves the count instead', (
    tester,
  ) async {
    // Applying creates a stock move; this user may not create one.
    final access = fakeAccess(denied: {'stock.move|create'});
    final result = await _open(tester, const Size(360, 640), access: access);

    expect(find.text('Create & Apply'), findsNothing);
    expect(find.text('Save Count'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('countedQuantityField')),
      '3',
    );
    await tester.tap(find.byKey(_applyKey));
    await tester.pumpAndSettle();

    expect(result.value?.countedQuantity, 3);
    expect(result.value?.apply, isFalse);
  });

  testWidgets('with the right to apply, the result applies the count', (
    tester,
  ) async {
    final result = await _open(
      tester,
      const Size(360, 640),
      access: fakeAccess(),
    );

    expect(find.text('Create & Apply'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('countedQuantityField')),
      '3',
    );
    await tester.tap(find.byKey(_applyKey));
    await tester.pumpAndSettle();

    expect(result.value?.apply, isTrue);
  });
}
