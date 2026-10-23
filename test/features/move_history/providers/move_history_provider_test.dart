import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/move_history/providers/move_history_provider.dart';
import 'package:mobo_inv_app/features/move_history/services/move_history_service.dart';

void main() {
  test("History opens on Odoo's Done filter, not on every move", () {
    final provider = MoveHistoryProvider();

    expect(provider.status, 'done');
    // The list, its count and its groups all read the filter through one
    // domain, so the pager's total is the Done moves' too.
    expect(MoveHistoryService.buildDomain(status: provider.status), [
      ['move_id.state', '=', 'done'],
    ]);
  });

  test('clearing the filters shows every move, as removing the facet does', () {
    final provider = MoveHistoryProvider()..clearFilters();

    expect(provider.status, isNull);
    expect(MoveHistoryService.buildDomain(status: provider.status), isEmpty);
  });

  test('resetting for another account or company restores the Done filter', () {
    final provider = MoveHistoryProvider()
      ..clearFilters()
      ..resetState();

    expect(provider.status, 'done');
  });
}
