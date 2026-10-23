import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../core/exceptions/odoo_error_mapper.dart';

/// What went wrong when ordering or automating an orderpoint, in the words
/// the user should see.
///
/// Odoo's `action_replenish` (17, 18 and 19) catches the procurement
/// `UserError` — "No rule has been found to replenish …", "There is no
/// matching vendor price …" — and re-raises it as a `RedirectWarning` whose
/// button is "Edit Product". Over JSON-RPC that arrives as an
/// [OdooException] whose `error['data']` holds the exception class in
/// `name` and Odoo's own sentence in `message`; printing the exception
/// itself showed the user a truncated dump of that map instead.
class ReplenishmentError {
  const ReplenishmentError({required this.message});

  /// The reason to show: Odoo's own message where there is one.
  final String message;

  factory ReplenishmentError.from(Object error) {
    if (error is OdooException && error.error is Map) {
      final data = (error.error as Map)['data'];
      if (data is Map) {
        final name = data['name']?.toString() ?? '';
        final message = _odooMessage(data);
        final isBusinessError =
            name.endsWith('RedirectWarning') ||
            name.endsWith('UserError') ||
            name.endsWith('ValidationError');
        if (isBusinessError && message.isNotEmpty) {
          return ReplenishmentError(message: message);
        }
      }
    }
    return ReplenishmentError(message: OdooErrorMapper.toUserMessage(error));
  }

  /// Just the sentence Odoo meant the user to read.
  ///
  /// `data['message']` is not it for a `RedirectWarning`: Odoo 18/19 build it
  /// as `"\n".join(map(str, exception.args))`, and those args are
  /// `(message, action, button_text, additional_context)` — so the message
  /// carries the action dict, "Edit Product" and "None" on the lines after
  /// it. The first argument is the message alone on 17, 18 and 19.
  static String _odooMessage(Map data) {
    final arguments = data['arguments'];
    if (arguments is List && arguments.isNotEmpty) {
      final first = arguments.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }

    final message = data['message']?.toString() ?? '';
    // Fallback: cut at the serialized action dict that follows the text.
    final actionStart = message.indexOf("\n{");
    return (actionStart == -1 ? message : message.substring(0, actionStart))
        .trim();
  }
}
