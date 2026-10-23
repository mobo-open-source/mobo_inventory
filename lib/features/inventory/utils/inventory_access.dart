import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/services/access_rights_service.dart';

/// The inventory screens' view of the user's Odoo access rights.
///
/// Wraps the app-wide [AccessRightsService], which fails open: every answer
/// is "allowed" until Odoo has definitely said no. [watch] subscribes the
/// calling widget, so an action disappears once a "no" arrives. Where no
/// service is provided (some widget tests) everything is allowed, matching
/// that fail-open behaviour.
class InventoryAccess {
  const InventoryAccess._(this._service);

  final AccessRightsService? _service;

  /// Reads the service from [context] and rebuilds the caller when its
  /// answers change. Call from `build`.
  static InventoryAccess watch(BuildContext context) {
    try {
      return InventoryAccess._(context.watch<AccessRightsService>());
    } on ProviderNotFoundException {
      return const InventoryAccess._(null);
    }
  }

  bool _can(String model, String operation) =>
      _service?.can(model, operation) ?? true;

  /// Create a product (the Inventory tab's create button).
  bool get canCreateProducts =>
      _can('product.template', 'create') && _can('product.product', 'create');

  /// Edit a product's details (Edit Product, Save Changes).
  bool get canEditProducts =>
      _can('product.template', 'write') && _can('product.product', 'write');

  /// Archive a product variant.
  bool get canArchiveProducts => _can('product.product', 'write');

  /// Record a stock count (the product row's "Edit" action).
  bool get canCountStock => _can('stock.quant', 'write');

  /// Apply a stock count (`stock.quant.action_apply_inventory`).
  bool get canApplyInventoryAdjustment =>
      _service?.canApplyInventoryAdjustment ?? true;
}
