import '../services/connectivity_service.dart';
import '../services/odoo_session_manager.dart';
import 'odoo_compat.dart';

/// Group membership of the signed-in user, for features Odoo itself only
/// shows to some groups.
class OdooUserGroups {
  OdooUserGroups._();

  /// Odoo's "Storage Locations" setting (Inventory > Settings). Without it
  /// Odoo hides the Locations menu and works with each warehouse's stock
  /// location only.
  static const String multiLocations = 'stock.group_stock_multi_locations';

  /// Whether the Settings option that grants the group [xmlId] is switched
  /// on — exactly what Odoo's checkbox shows: every internal user
  /// (`base.group_user`) implies the group. Null when the server could not
  /// tell.
  ///
  /// Unlike [has], a user who still holds the group with the option off —
  /// added to it by hand, or left over from before it was switched off —
  /// does not count. Falls back to [has] when the groups cannot be read.
  static Future<bool?> settingEnabled(String xmlId) async {
    try {
      final internalUserId = await _groupId('base.group_user');
      final groupId = await _groupId(xmlId);
      if (internalUserId != null && groupId != null) {
        final count = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'res.groups',
          'method': 'search_count',
          'args': [
            [
              ['id', '=', internalUserId],
              [
                'implied_ids',
                'in',
                [groupId],
              ],
            ],
          ],
          'kwargs': const {},
        });
        if (count is int) return count > 0;
      }
    } catch (e) {
      if (e is NoInternetException || e is ServerUnreachableException) {
        rethrow;
      }
    }
    return has(xmlId);
  }

  /// The id of the `res.groups` record [xmlId] names. `ir.model.data` itself
  /// is not readable by ordinary users, but this lookup is.
  static Future<int?> _groupId(String xmlId) async {
    final dot = xmlId.indexOf('.');
    if (dot <= 0) return null;
    final result = await OdooSessionManager.safeCallKwWithoutCompany({
      'model': 'ir.model.data',
      'method': 'check_object_reference',
      'args': [xmlId.substring(0, dot), xmlId.substring(dot + 1)],
      'kwargs': const {},
    });
    if (result is List && result.length == 2 && result[1] is int) {
      return result[1] as int;
    }
    return null;
  }

  /// Whether the current user belongs to the group with external id [xmlId],
  /// or null when the server could not tell.
  ///
  /// `res.users.has_group` is an `@api.model` method taking just the group up
  /// to Odoo 17 and a record method from 18 on, so the shape the version
  /// calls for is tried first, then the other.
  static Future<bool?> has(String xmlId) async {
    final session = await OdooSessionManager.getCurrentSession();
    final uid = session?.userId;
    if (uid == null) return null;

    final recordForm = [
      [uid],
      xmlId,
    ];
    final modelForm = [xmlId];
    final attempts = (await OdooCompat.current()).major >= 18
        ? [recordForm, modelForm]
        : [modelForm, recordForm];

    for (final args in attempts) {
      try {
        final result = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': args,
          'kwargs': const {},
        });
        if (result is bool) return result;
      } catch (e) {
        if (e is NoInternetException || e is ServerUnreachableException) {
          rethrow;
        }
      }
    }
    return null;
  }
}
