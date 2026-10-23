import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/odoo/odoo_compat.dart';

void main() {
  group('OdooCompat stock.move fields', () {
    test('uses product_uom up to Odoo 19 and uom_id from Odoo 20', () {
      expect(const OdooCompat(16).stockMoveUomField, 'product_uom');
      expect(const OdooCompat(19).stockMoveUomField, 'product_uom');
      expect(const OdooCompat(20).stockMoveUomField, 'uom_id');
    });

    test('sends name only before Odoo 19', () {
      expect(const OdooCompat(18).stockMoveHasName, isTrue);
      expect(const OdooCompat(19).stockMoveHasName, isFalse);
      expect(const OdooCompat(20).stockMoveHasName, isFalse);
    });
  });

  group('OdooCompat Odoo 20 renames', () {
    test('mrp.production unit field', () {
      expect(const OdooCompat(19).mrpProductionUomField, 'product_uom_id');
      expect(const OdooCompat(20).mrpProductionUomField, 'uom_id');
    });

    test('stock.picking move field and date', () {
      expect(
        const OdooCompat(18).pickingMoveIdsField,
        'move_ids_without_package',
      );
      expect(const OdooCompat(19).pickingMoveIdsField, 'move_ids');
      expect(const OdooCompat(20).pickingMoveIdsField, 'move_ids');
      expect(const OdooCompat(18).pickingHasDateField, isTrue);
      expect(const OdooCompat(19).pickingHasDateField, isFalse);
    });

    test('read_group is legacy only before Odoo 20', () {
      expect(const OdooCompat(17).hasLegacyReadGroup, isTrue);
      expect(const OdooCompat(19).hasLegacyReadGroup, isTrue);
      expect(const OdooCompat(20).hasLegacyReadGroup, isFalse);
    });

    test('zero-demand check is skipped only on Odoo 20', () {
      expect(const OdooCompat(19).confirmPickingContext, isEmpty);
      expect(const OdooCompat(20).confirmPickingContext, {
        'skip_zero_demand_check': true,
      });
    });

    test('action_id is self-writable only before Odoo 20', () {
      expect(const OdooCompat(19).userSelfWritableFields, contains('action_id'));
      expect(
        const OdooCompat(20).userSelfWritableFields,
        isNot(contains('action_id')),
      );
      expect(const OdooCompat(20).userSelfWritableFields, contains('phone'));
    });

    test('Odoo 20 is a supported release', () {
      expect(const OdooCompat(20).isUntested, isFalse);
      expect(const OdooCompat(21).isUntested, isTrue);
    });
  });
}
