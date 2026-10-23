import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/utils/odoo_value.dart';
import 'package:mobo_inv_app/features/picking/models/picking_model.dart';

void main() {
  group('odooString', () {
    test('treats Odoo empty values as missing', () {
      expect(odooString(false), isNull);
      expect(odooString(null), isNull);
      expect(odooString('  '), isNull);
      // Written to the offline cache by an older build.
      expect(odooString('false'), isNull);
    });

    test('keeps real values', () {
      expect(odooString('S00077'), 'S00077');
      expect(odooString(42), '42');
    });
  });

  test('a picking with no source document has no origin', () {
    final picking = Picking.fromJson({
      'id': 1,
      'name': 'WH/OUT/00051',
      'state': 'assigned',
      'picking_type_code': 'outgoing',
      'scheduled_date': '2027-01-08 10:02:26',
      'origin': false,
      'partner_id': false,
    });

    expect(picking.origin, isNull);
    expect(picking.partnerName, isNull);
    expect(picking.scheduledDate, '2027-01-08 10:02:26');
  });
}
