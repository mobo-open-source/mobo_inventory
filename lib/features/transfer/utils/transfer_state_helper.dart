import 'package:flutter/material.dart';

import '../../../core/services/access_rights_service.dart';
import '../../../core/theme/app_theme.dart';

/// Helper class for managing and formatting transfer states and their visual representations.
class TransferStateHelper {
  static String getStateLabel(String? state) {
    if (state == null) return 'Unknown';

    switch (state) {
      case 'draft':
        return 'Draft';
      case 'waiting':
        return 'Waiting Another Operation';
      case 'confirmed':
        return 'Waiting';
      case 'assigned':
        return 'Ready';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  static Color getStateColor(String? state) => StatusColors.forState(state);

  static bool canEdit(String? state) {
    return state != 'done' && state != 'cancel';
  }

  static bool canMarkAsTodo(String? state) {
    return state == 'draft';
  }

  static bool canValidate(String? state) {
    return state == 'confirmed' || state == 'waiting' || state == 'assigned';
  }

  static bool canCancel(String? state) {
    return state != 'done' && state != 'cancel';
  }

  /// Whether the user's Odoo access rights allow creating a transfer: the
  /// picking and its moves.
  static bool hasCreateRights(AccessRightsService access) =>
      access.can('stock.picking', 'create') &&
      access.can('stock.move', 'create');

  /// Whether the user's Odoo access rights allow editing a transfer. Saving
  /// rewrites the picking and deletes and recreates its moves.
  static bool hasEditRights(AccessRightsService access) =>
      access.can('stock.picking', 'write') &&
      access.can('stock.move', 'unlink') &&
      access.can('stock.move', 'create');

  /// Whether the user may cancel a transfer or mark it as to do.
  static bool hasWriteRights(AccessRightsService access) =>
      access.can('stock.picking', 'write');

  /// Whether the user may validate a transfer, which also writes its moves.
  static bool hasValidateRights(AccessRightsService access) =>
      access.can('stock.picking', 'write') && access.can('stock.move', 'write');
}
