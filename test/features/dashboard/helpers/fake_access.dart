import 'package:mobo_inv_app/core/services/access_rights_service.dart';

/// Answers access questions from fixed deny lists: models the user may not
/// read, and groups they are not in.
class FakeDashboardAccessProbe implements AccessRightsProbe {
  FakeDashboardAccessProbe({
    this.unreadable = const {},
    this.missingGroups = const {},
  });

  final Set<String> unreadable;
  final Set<String> missingGroups;

  @override
  Future<bool> hasAccess(AccessAccount account, AccessCheck check) async =>
      !(check.operation == 'read' && unreadable.contains(check.model));

  @override
  Future<bool> hasGroup(AccessAccount account, String groupXmlId) async =>
      !missingGroups.contains(groupXmlId);
}

/// An [AccessRightsService] for an Odoo 20 user. Build it inside the test
/// body and pump until its answers have arrived.
AccessRightsService fakeDashboardAccess({
  Set<String> unreadable = const {},
  Set<String> missingGroups = const {},
}) => AccessRightsService.forTesting(
  probe: FakeDashboardAccessProbe(
    unreadable: unreadable,
    missingGroups: missingGroups,
  ),
  readAccount: () => const AccessAccount(
    serverUrl: 'http://odoo.test',
    database: 'test',
    userId: 2,
    companyId: 1,
    serverMajor: 20,
  ),
);

/// A user with no Inventory rights at all: Odoo 20 still lets every
/// internal user read warehouses, locations and quants.
AccessRightsService noInventoryRightsAccess() => fakeDashboardAccess(
  unreadable: const {
    'stock.picking',
    'stock.move',
    'stock.move.line',
    'mrp.production',
    'stock.warehouse.orderpoint',
    'product.product',
  },
  missingGroups: const {
    AccessRightsService.stockUserGroup,
    AccessRightsService.stockManagerGroup,
  },
);
