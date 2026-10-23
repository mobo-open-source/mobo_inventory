import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/manufacturing/services/manufacturing_service.dart';
import 'package:mobo_inv_app/features/picking/services/picking_service.dart';

/// The dashboard's counts are built from the same domain builders and states
/// as the lists its cards open, so each card's number is its list's total.
void main() {
  group('Dashboard count domains', () {
    test(
      'Delivery Orders, Receipts and Internal Transfers count Ready only',
      () {
        for (final code in ['outgoing', 'incoming', 'internal']) {
          expect(
            PickingService.buildDomain(
              pickingTypeCode: code,
              states: PickingService.toProcessStates,
            ),
            [
              ['picking_type_code', '=', code],
              ['state', '=', 'assigned'],
            ],
          );
        }
      },
    );

    test('PoS orders are counted apart from Delivery Orders, as in Odoo', () {
      const posTypes = [12, 15];
      expect(
        PickingService.buildDomain(
          pickingTypeCode: 'outgoing',
          states: PickingService.toProcessStates,
          excludedPickingTypeIds: posTypes,
        ),
        [
          ['picking_type_code', '=', 'outgoing'],
          ['picking_type_id', 'not in', posTypes],
          ['state', '=', 'assigned'],
        ],
      );
      expect(
        PickingService.buildDomain(
          pickingTypeCode: 'outgoing',
          states: PickingService.toProcessStates,
          pickingTypeIds: posTypes,
        ),
        [
          ['picking_type_code', '=', 'outgoing'],
          ['picking_type_id', 'in', posTypes],
          ['state', '=', 'assigned'],
        ],
      );
    });

    test('Manufacturing Orders count Odoo\'s "To Do" orders', () {
      expect(ManufacturingService.toDoStates, [
        'draft',
        'confirmed',
        'progress',
        'to_close',
      ]);
      expect(
        ManufacturingService.buildDomain(
          states: ManufacturingService.toDoStates,
        ),
        [
          '|',
          '|',
          '|',
          ['state', '=', 'draft'],
          ['state', '=', 'confirmed'],
          ['state', '=', 'progress'],
          ['state', '=', 'to_close'],
        ],
      );
    });
  });
}
