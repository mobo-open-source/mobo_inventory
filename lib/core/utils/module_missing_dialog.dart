import 'package:flutter/material.dart';

import '../../shared/widgets/dialogs/access_denied_dialog.dart';
import '../services/inventory_access_service.dart';

/// Displays a blocking dialog for a server that doesn't have the required
/// "Inventory" module installed.
///
/// [onClose] runs after the dialog has been popped — callers reached
/// mid-flow (adding a second account, switching accounts) use it to leave
/// that flow instead of leaving the user on a form for a server they can't
/// use. Shares [showAccessDeniedDialog]'s layout so both blocking dialogs in
/// the login flow look and close the same way.
Future<void> showModuleMissingDialog(
  BuildContext context, {
  String actionLabel = 'Back to Login',
  VoidCallback? onClose,
}) {
  return showAccessDeniedDialog(
    context,
    title: 'Module Missing',
    message: InventoryAccessService.moduleMissingMessage,
    actionLabel: actionLabel,
    onClose: onClose,
  );
}
