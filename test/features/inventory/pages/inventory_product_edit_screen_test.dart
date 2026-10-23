import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/access_rights_service.dart';
import 'package:mobo_inv_app/features/inventory/pages/inventory_product_edit_screen.dart';
import 'package:provider/provider.dart';
import 'package:mobo_inv_app/features/inventory/viewmodels/inventory_product_edit_view_model.dart';

import '../helpers/fake_access.dart';
import '../helpers/fake_odoo.dart';

String _fieldText(WidgetTester tester, String label) {
  // Form fields put their label (a Text.rich, for the required star) above
  // the input in one Column.
  final labelFinder = find.textContaining(label, findRichText: true);
  final column = find
      .ancestor(of: labelFinder.first, matching: find.byType(Column))
      .first;
  final field = find.descendant(
    of: column,
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(field.first).controller.text;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  bool settle = true,
  AccessRightsService? access,
}) async {
  // A tall phone, so the lazily built form lays out down to the units.
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final app = MaterialApp(home: screen);
  await tester.pumpWidget(
    access == null
        ? app
        : ChangeNotifierProvider<AccessRightsService>.value(
            value: access,
            child: app,
          ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // The error state's Lottie animation loops, so it never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('edit mode opens prefilled with the existing product', (
    tester,
  ) async {
    final vm = InventoryProductEditViewModel(callKw: FakeOdoo().call);
    await _pump(
      tester,
      InventoryProductEditScreen(productId: 74, viewModel: vm),
    );

    expect(find.text('Edit Product'), findsOneWidget);
    expect(_fieldText(tester, 'Product Name'), 'Screw');
    expect(_fieldText(tester, 'SKU/Default Code'), 'CONS_25630');
    expect(_fieldText(tester, 'Barcode'), '20133785543124');
    expect(_fieldText(tester, 'Category'), 'Goods');
    expect(_fieldText(tester, 'List Price'), '0.20');
    expect(_fieldText(tester, 'Cost Price'), '0.10');
    expect(_fieldText(tester, 'Unit of Measure'), 'Units');

    // The current image, not the placeholder icon.
    final imageBox = find.byKey(const ValueKey('productImage'));
    expect(
      find.descendant(of: imageBox, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: imageBox, matching: find.byIcon(Icons.image)),
      findsNothing,
    );

    // Nothing changed yet, so nothing to save.
    final save = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Save Changes'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets(
    'a product that cannot be read shows an error, not a blank form',
    (tester) async {
      final vm = InventoryProductEditViewModel(
        callKw: FakeOdoo(failRead: true).call,
      );
      await _pump(
        tester,
        InventoryProductEditScreen(productId: 74, viewModel: vm),
        settle: false,
      );

      expect(find.text('Couldn\'t load this product'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Product Name'), findsNothing);
    },
  );

  testWidgets('create mode opens an empty form with server defaults', (
    tester,
  ) async {
    final vm = InventoryProductEditViewModel(callKw: FakeOdoo().call);
    await _pump(tester, InventoryProductEditScreen(viewModel: vm));

    expect(find.text('Create Product'), findsWidgets);
    expect(_fieldText(tester, 'Product Name'), '');
    expect(_fieldText(tester, 'Unit of Measure'), 'Units');
    expect(find.text('Track Inventory'), findsOneWidget);
    // Name and category are still required.
    final create = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Create Product'),
    );
    expect(create.onPressed, isNull);
  });

  testWidgets('Save Changes is withheld from users who cannot write', (
    tester,
  ) async {
    final vm = InventoryProductEditViewModel(callKw: FakeOdoo().call);
    await _pump(
      tester,
      InventoryProductEditScreen(productId: 74, viewModel: vm),
      access: fakeAccess(denied: {'product.template|write'}),
    );

    expect(_fieldText(tester, 'Product Name'), 'Screw');
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('Save Changes shows for users who can write', (tester) async {
    final vm = InventoryProductEditViewModel(callKw: FakeOdoo().call);
    await _pump(
      tester,
      InventoryProductEditScreen(productId: 74, viewModel: vm),
      access: fakeAccess(),
    );

    expect(find.text('Save Changes'), findsOneWidget);
  });
}
