import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

class OdooErrorMapper {
  static String toUserMessage(Object error) {
    final raw = error.toString();

    if (error is NoInternetException) {
      return 'No internet connection. Please check Wi‑Fi or mobile data and try again.';
    }
    if (error is ServerUnreachableException) {
      return 'Cannot reach the server. Please verify the server URL and your network connection.';
    }

    final modelKeyErr = RegExp(r"KeyError: '([a-zA-Z0-9_.]+)'");
    final match = modelKeyErr.firstMatch(raw);
    if (match != null) {
      final model = match.group(1) ?? '';
      final hint = _moduleHintForModel(model);
      final message = StringBuffer(
        'Missing Module: The "$model" data model is not available.\n\n',
      );
      if (hint != null) {
        message.write(hint);
      } else {
        message.write(
          'This feature requires a module that is not installed on your Odoo server.',
        );
      }
      message.write(
        '\n\nPlease contact your administrator to install the required app.',
      );
      return message.toString();
    }

    if (raw.contains('model') &&
        (raw.contains('not found') || raw.contains('does not exist'))) {
      return 'Required module not found. The feature you\'re trying to access requires an Odoo app that is not installed. Please contact your administrator.';
    }

    if (raw.contains('werkzeug.exceptions.NotFound') ||
        raw.contains('404 Not Found')) {
      return 'Server resource not found. This may indicate:\n'
          '• Missing Odoo modules/apps\n'
          '• Insufficient permissions\n'
          '• Incorrect server configuration\n\n'
          'Please verify your access rights and installed apps.';
    }

    if (raw.contains('Access Denied') || raw.contains('AccessError')) {
      return 'Access Denied. You don\'t have permission to access this feature. Please contact your administrator to grant the necessary access rights.';
    }

    if (raw.contains('authentication') ||
        (raw.contains('uid') && raw.contains('context'))) {
      return 'Authentication failed or your session is invalid. Please sign in again and retry.';
    }

    if (raw.contains('database') && raw.contains('not exist')) {
      return 'Database not found. Please verify your database name and server configuration.';
    }

    return 'Unexpected server error. Please try again or contact support.';
  }

  static String? _moduleHintForModel(String model) {
    switch (model) {
      case 'stock.picking':
      case 'stock.picking.type':
        return '📦 Required App: Inventory\n'
            'This feature needs the "Inventory" app to manage stock transfers and operations.';

      case 'stock.move':
      case 'stock.move.line':
        return '📦 Required App: Inventory\n'
            'This feature needs the "Inventory" app to track stock movements.';

      case 'stock.quant':
      case 'stock.location':
      case 'stock.warehouse':
        return '📦 Required App: Inventory\n'
            'This feature needs the "Inventory" app to manage warehouses and stock quantities.';

      case 'product.product':
      case 'product.template':
        return '🏷️ Required App: Product (Sales/Inventory)\n'
            'This feature needs the "Product" module which comes with Sales or Inventory apps.';

      case 'product.category':
        return '🏷️ Required App: Product\n'
            'This feature needs product categorization which comes with Sales or Inventory apps.';

      case 'mrp.production':
      case 'mrp.bom':
      case 'mrp.workcenter':
        return '🏭 Required App: Manufacturing\n'
            'This feature needs the "Manufacturing" app to manage production orders.';

      case 'purchase.order':
      case 'purchase.order.line':
        return '🛒 Required App: Purchase\n'
            'This feature needs the "Purchase" app to manage supplier orders.';

      case 'sale.order':
      case 'sale.order.line':
        return '💰 Required App: Sales\n'
            'This feature needs the "Sales" app to manage customer orders.';

      case 'account.move':
      case 'account.invoice':
        return '💳 Required App: Accounting\n'
            'This feature needs the "Accounting" app to manage invoices and journal entries.';

      case 'hr.employee':
      case 'hr.attendance':
        return '👥 Required App: HR/Attendance\n'
            'This feature needs the "Employees" or "Attendance" app.';

      case 'res.partner':
        return '👤 Required App: Contacts\n'
            'This feature needs the "Contacts" app (usually installed by default).';

      default:
        return null;
    }
  }
}
