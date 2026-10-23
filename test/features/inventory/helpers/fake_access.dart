import 'package:mobo_inv_app/core/services/access_rights_service.dart';

/// Answers access questions from a fixed deny list (`'model|operation'`).
class FakeAccessProbe implements AccessRightsProbe {
  FakeAccessProbe({this.denied = const {}});

  final Set<String> denied;

  @override
  Future<bool> hasAccess(AccessAccount account, AccessCheck check) async =>
      !denied.contains(check.cacheKey);

  @override
  Future<bool> hasGroup(AccessAccount account, String groupXmlId) async => true;
}

/// An [AccessRightsService] for an Odoo 20 user denied exactly [denied].
/// Build it inside the test body, so its startup work runs in the test's
/// clock, and pump until settled for the answers to arrive.
AccessRightsService fakeAccess({Set<String> denied = const {}}) =>
    AccessRightsService.forTesting(
      probe: FakeAccessProbe(denied: denied),
      readAccount: () => const AccessAccount(
        serverUrl: 'http://odoo.test',
        database: 'test',
        userId: 2,
        companyId: 1,
        serverMajor: 20,
      ),
    );
