import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/move_history/services/move_history_service.dart';

void main() {
  test('History filters build a domain in Odoo prefix notation', () {
    expect(
      MoveHistoryService.buildDomain(
        searchQuery: 'desk',
        pickingTypeCodes: ['outgoing', 'internal'],
        inventoryOnly: true,
      ),
      [
        '|',
        ['product_id', 'ilike', 'desk'],
        ['reference', 'ilike', 'desk'],
        '|',
        ['picking_id.picking_type_id.code', '=', 'outgoing'],
        ['picking_id.picking_type_id.code', '=', 'internal'],
        ['move_id.is_inventory', '=', true],
      ],
    );
  });

  test('Active Only takes precedence over a status', () {
    expect(MoveHistoryService.buildDomain(activeOnly: true, status: 'done'), [
      [
        'move_id.state',
        'not in',
        ['done', 'draft', 'cancel'],
      ],
    ]);
  });
}
