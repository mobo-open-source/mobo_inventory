import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/inventory/viewmodels/inventory_product_edit_view_model.dart';

import '../helpers/fake_odoo.dart';

void main() {
  group('load (edit mode)', () {
    test('prefills every field from product.product, image included', () async {
      final odoo = FakeOdoo();
      final vm = InventoryProductEditViewModel(callKw: odoo.call);

      await vm.load(74);

      expect(vm.error, isNull);
      expect(vm.recordLoaded, isTrue);
      expect(vm.isCreateMode, isFalse);
      expect(vm.name, 'Screw');
      expect(vm.sku, 'CONS_25630');
      expect(vm.barcode, '20133785543124');
      expect(vm.listPrice, 0.2);
      expect(vm.standardPrice, 0.1);
      expect(vm.weight, 0.01);
      expect(vm.categId, 1);
      expect(vm.uomId, 1);
      expect(vm.taxes, [1, 8]);
      expect(vm.templateId, 56);
      // Odoo 20 sends binaries as {content, size, filename}.
      expect(vm.imageBase64, FakeOdoo.pngBase64);
      expect(vm.imageBytes, base64Decode(FakeOdoo.pngBase64));
      expect(vm.hasUnsavedChanges, isFalse);
      expect(vm.canSave, isFalse);
    });

    test(
      'drops fields the server lacks instead of failing the whole read',
      () async {
        // An Inventory-only database: no Sales (sale_delay), no Invoicing
        // (taxes_id). Odoo rejects a read naming either one outright, which
        // is what left the edit form blank.
        final odoo = FakeOdoo(missingFields: {'sale_delay', 'taxes_id'});
        final vm = InventoryProductEditViewModel(callKw: odoo.call);

        await vm.load(74);

        final read = odoo.calls.firstWhere(
          (c) => c['model'] == 'product.product' && c['method'] == 'read',
        );
        final fields = (read['kwargs'] as Map)['fields'] as List;
        expect(fields, isNot(contains('sale_delay')));
        expect(fields, isNot(contains('taxes_id')));
        expect(fields, contains('name'));
        expect(vm.error, isNull);
        expect(vm.recordLoaded, isTrue);
        expect(vm.name, 'Screw');
        expect(vm.hasTaxesField, isFalse);
        // account.tax is not even queried.
        expect(odoo.calls.where((c) => c['model'] == 'account.tax'), isEmpty);
      },
    );

    test('a failed read is reported, not shown as an empty form', () async {
      final odoo = FakeOdoo(failRead: true);
      final vm = InventoryProductEditViewModel(callKw: odoo.call);

      await vm.load(74);

      expect(vm.recordLoaded, isFalse);
      expect(vm.error, isNotNull);
      expect(vm.loading, isFalse);
      expect(vm.canSave, isFalse);
    });

    test(
      'keeps the record\'s category labelled when outside the option list',
      () async {
        final odoo = FakeOdoo(categoryOptions: const []);
        final vm = InventoryProductEditViewModel(callKw: odoo.call);

        await vm.load(74);

        expect(vm.categoryOptions, [
          {'value': '1', 'label': 'Goods'},
        ]);
      },
    );
  });

  group('save (edit mode)', () {
    test('writes only what changed, to the record that owns it', () async {
      final odoo = FakeOdoo();
      final vm = InventoryProductEditViewModel(callKw: odoo.call);
      await vm.load(74);
      odoo.calls.clear();

      vm.setName('Screw M4');
      vm.setBarcode('999');
      expect(vm.canSave, isTrue);

      expect(await vm.save(), isTrue);

      final writes = odoo.calls.where((c) => c['method'] == 'write').toList();
      expect(writes, hasLength(2));
      expect(writes[0]['model'], 'product.product');
      expect(writes[0]['args'], [
        [74],
        {'barcode': '999'},
      ]);
      expect(writes[1]['model'], 'product.template');
      expect(writes[1]['args'], [
        [56],
        {'name': 'Screw M4'},
      ]);
      expect(vm.hasUnsavedChanges, isFalse);
    });

    test('never writes the computed currency or unchanged values', () async {
      final odoo = FakeOdoo();
      final vm = InventoryProductEditViewModel(callKw: odoo.call);
      await vm.load(74);
      odoo.calls.clear();

      vm.setCurrency(2);
      vm.setListPrice(1.5);
      await vm.save();

      final writes = odoo.calls.where((c) => c['method'] == 'write').toList();
      expect(writes, hasLength(1));
      expect(writes.single['args'], [
        [56],
        {'list_price': 1.5},
      ]);
    });

    test('removing the image clears it in Odoo', () async {
      final odoo = FakeOdoo();
      final vm = InventoryProductEditViewModel(callKw: odoo.call);
      await vm.load(74);
      odoo.calls.clear();

      vm.setImage(null);
      await vm.save();

      final write = odoo.calls.singleWhere((c) => c['method'] == 'write');
      expect(write['model'], 'product.product');
      expect(write['args'], [
        [74],
        {'image_1920': false},
      ]);
    });
  });

  group('create mode', () {
    test('starts from the server defaults and creates a template', () async {
      final odoo = FakeOdoo();
      final vm = InventoryProductEditViewModel(callKw: odoo.call);

      await vm.initCreate();

      expect(vm.isCreateMode, isTrue);
      expect(vm.recordLoaded, isTrue);
      expect(vm.uomId, 1);
      expect(vm.taxes, [1, 8]);
      expect(vm.canTrackInventory, isTrue);
      // Name and category still missing.
      expect(vm.canSave, isFalse);

      vm.setName('Washer');
      vm.setCategory(1);
      expect(vm.canSave, isTrue);

      expect(await vm.save(), isTrue);
      expect(vm.createdTemplateId, 900);

      final create = odoo.calls.singleWhere((c) => c['method'] == 'create');
      expect(create['model'], 'product.template');
      final vals = (create['args'] as List).single as Map;
      expect(vals['name'], 'Washer');
      expect(vals['categ_id'], 1);
      expect(vals['uom_id'], 1);
      expect(vals['is_storable'], isTrue);
      expect(vals['taxes_id'], [
        [
          6,
          0,
          [1, 8],
        ],
      ]);
      expect(vals.containsKey('currency_id'), isFalse);
    });

    test('leaves out fields the server lacks', () async {
      final odoo = FakeOdoo(missingFields: {'taxes_id', 'is_storable'});
      final vm = InventoryProductEditViewModel(callKw: odoo.call);
      await vm.initCreate();

      vm.setName('Washer');
      vm.setCategory(1);
      await vm.save();

      final create = odoo.calls.singleWhere((c) => c['method'] == 'create');
      final vals = (create['args'] as List).single as Map;
      expect(vals.containsKey('taxes_id'), isFalse);
      expect(vals.containsKey('is_storable'), isFalse);
      // Before Odoo 18 the storable type stands in for is_storable.
      expect(vals['type'], 'product');
    });
  });
}
