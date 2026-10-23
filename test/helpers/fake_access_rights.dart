import 'package:mobo_inv_app/core/services/access_rights_service.dart';

/// Answers every access question from a fixed deny-list instead of a server.
class _DenyListProbe implements AccessRightsProbe {
  _DenyListProbe(this.denied);

  final Set<String> denied;

  @override
  Future<bool> hasAccess(AccessAccount account, AccessCheck check) async =>
      !denied.contains(check.cacheKey);

  @override
  Future<bool> hasGroup(AccessAccount account, String groupXmlId) async =>
      !denied.contains('group:$groupXmlId');
}

/// An [AccessRightsService] for widget tests. Everything is allowed except
/// the [denied] checks, given as `'model|operation'` (e.g.
/// `'stock.move|create'`). Answers arrive asynchronously, as from a server,
/// so pump a frame or two before expecting a denied action to be hidden.
AccessRightsService fakeAccessRights({Set<String> denied = const {}}) {
  return AccessRightsService.forTesting(
    probe: _DenyListProbe(denied),
    readAccount: () => const AccessAccount(
      serverUrl: 'https://odoo.test',
      database: 'test',
      userId: 2,
      companyId: 1,
    ),
  );
}
