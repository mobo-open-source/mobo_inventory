import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/transfer/models/transfer_model.dart';
import 'package:mobo_inv_app/features/transfer/pages/transfer_form_screen.dart';
import 'package:mobo_inv_app/features/transfer/providers/transfer_provider.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/layout/landscape_test_helpers.dart';

/// Serves one transfer's form data without a network.
class _FakeTransferProvider extends TransferProvider {
  _FakeTransferProvider(this.transfer);

  final InternalTransfer transfer;

  @override
  List<Map<String, dynamic>> get pickingTypes => [
    {
      'id': 5,
      'name': 'Internal Transfers',
      'display_name': 'YourCompany: Internal Transfers',
      'code': 'internal',
    },
  ];

  @override
  List<Map<String, dynamic>> get locations => [
    {'id': 1, 'name': 'Order Processing', 'complete_name': 'WH/Input/Order'},
    {'id': 2, 'name': 'Stock', 'complete_name': 'WH/Stock'},
  ];

  @override
  Future<void> fetchPickingTypes() async {}

  @override
  Future<void> fetchLocations() async {}

  @override
  Future<InternalTransfer?> fetchTransferDetails(int transferId) async =>
      transfer;
}

InternalTransfer _transfer() => InternalTransfer(
  id: 21,
  name: 'WH/INT/00021',
  pickingTypeId: 5,
  pickingTypeName: 'YourCompany: Internal Transfers',
  locationId: 1,
  locationDestId: 2,
  scheduledDate: '2026-10-30 09:00:00',
  state: 'confirmed',
  moveLines: [
    TransferLine(
      id: 1,
      productId: 7,
      productName: 'Acoustic Bloc Screens (Black, 3XL)',
      quantity: 1,
      productUom: '1',
      unitPrice: 100,
    ),
  ],
);

/// [wide] gives a surface on which the test font (every glyph a full em)
/// wraps no label, so only the fields' own geometry shows in a measurement.
Future<void> _openForm(WidgetTester tester, {bool wide = false}) async {
  if (wide) {
    tester.view.physicalSize = const Size(3600, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  } else {
    setPortraitPhone(tester);
  }
  // The test font makes every glyph a full em wide, so unrelated rows (the
  // totals box) report overflows that a real font does not have.
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    onError?.call(details);
  };
  addTearDown(() => FlutterError.onError = onError);

  final transfer = _transfer();
  await tester.pumpWidget(
    ChangeNotifierProvider<TransferProvider>.value(
      value: _FakeTransferProvider(transfer),
      child: MaterialApp(home: TransferFormScreen(transfer: transfer)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _fieldWithAlign(TextAlign align) => find.byWidgetPredicate(
  (w) => w is TextField && w.textAlign == align,
  description: 'TextField aligned $align',
);

/// How far the typed text's centre is below the centre of its field.
double _textOffset(WidgetTester tester, Finder field) {
  final box = tester.getRect(field);
  final text = tester.getRect(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  return text.center.dy - box.center.dy;
}

void main() {
  testWidgets('Quantity and Unit Price: same size, text on the same line', (
    tester,
  ) async {
    await _openForm(tester, wide: true);

    final quantity = _fieldWithAlign(TextAlign.center);
    final price = _fieldWithAlign(TextAlign.right);
    expect(quantity, findsOneWidget);
    expect(price, findsOneWidget);

    final q = tester.getRect(quantity);
    final p = tester.getRect(price);
    expect(p.height, q.height, reason: 'the two fields differ in height');
    expect(p.width, q.width, reason: 'the two fields differ in width');
    expect(p.top, q.top, reason: 'the two fields do not line up');

    // Text sits on the same line in both, and in the middle of the field.
    expect(
      _textOffset(tester, price),
      moreOrLessEquals(_textOffset(tester, quantity), epsilon: 0.5),
    );
    expect(_textOffset(tester, quantity).abs(), lessThanOrEqualTo(1));

    // The currency prefix is centred as well.
    final usd = tester.getRect(
      find.descendant(of: price, matching: find.text('USD')),
    );
    expect(usd.center.dy, moreOrLessEquals(p.center.dy, epsilon: 1));
  });

  testWidgets('Quantity and Unit Price share the card width, not a third '
      'of it each with the Total', (tester) async {
    await _openForm(tester);

    // With the Total beside them each was ~88px: too narrow for the price
    // once "USD" took its share. Now they have the row to themselves.
    expect(
      tester.getSize(_fieldWithAlign(TextAlign.center)).width,
      greaterThanOrEqualTo(110),
    );
    expect(
      tester.getSize(_fieldWithAlign(TextAlign.right)).width,
      greaterThanOrEqualTo(110),
    );
    // The Total is still there, under them.
    expect(find.text('Total'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Total')).dy,
      greaterThan(tester.getBottomLeft(_fieldWithAlign(TextAlign.right)).dy),
    );
  });

  testWidgets('Transfer Details inputs read alike: one size, weight, colour, '
      'and the date box is as tall as the dropdowns', (tester) async {
    await _openForm(tester);

    // The location dropdowns' value text ...
    final locationField = find.widgetWithText(TextField, 'WH/Input/Order');
    final location = tester.widget<TextField>(locationField).style!;
    // ... and the date input's value.
    final dateText = find.text('30/10/2026');
    final date = tester.widget<Text>(dateText).style!;

    expect(date.fontSize, location.fontSize);
    expect(date.fontWeight, location.fontWeight);
    expect(date.color, location.color);

    final dateBox = find.ancestor(of: dateText, matching: find.byType(Container));
    expect(
      tester.getSize(dateBox.first).height,
      tester.getSize(locationField).height,
    );
  });
}
