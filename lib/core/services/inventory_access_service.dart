import 'odoo_session_manager.dart';

/// Thrown when an account being switched to (or added) cannot use this app
/// because the server is missing the required "Inventory" module, so the
/// caller can show the specific dialog instead of a generic failure.
class InventoryModuleMissingException implements Exception {
  const InventoryModuleMissingException();

  @override
  String toString() => InventoryAccessService.moduleMissingMessage;
}

/// Thrown when an account being switched to (or added) cannot use this app
/// because the user is a portal user, so the caller can tell the user why
/// instead of reporting a generic failure.
class InventoryAccessDeniedException implements Exception {
  const InventoryAccessDeniedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Checks whether the currently authenticated session is allowed to use this
/// app: the `stock` module must be installed on the server, and the signed-in
/// user must not be a portal/public user.
///
/// Both checks read the *current* session fresh on every call rather than
/// caching, so an account switch is never judged against a stale answer
/// computed for the previous account.
class InventoryAccessService {
  static String? _pendingSignOutMessage;

  /// Records [message] to be shown once the app lands back on the
  /// server-setup screen after [AppEntry] signs a user out because their
  /// already-active session failed the module/access check on resume.
  static void setPendingSignOutMessage(String message) {
    _pendingSignOutMessage = message;
  }

  /// Returns the message set by [setPendingSignOutMessage], clearing it so
  /// it is only ever shown once.
  static String? consumePendingSignOutMessage() {
    final message = _pendingSignOutMessage;
    _pendingSignOutMessage = null;
    return message;
  }

  /// User-facing message for a portal-user denial, shared by every call site
  /// so the wording never drifts between the login, add-account, switch and
  /// resume paths.
  static const String portalUserMessage =
      'Portal users cannot use this app. Please log in with an internal '
      'user account.';

  /// User-facing message for the required module being missing.
  static const String moduleMissingMessage =
      'The required "Inventory" module is not installed on this server. '
      'Please contact your administrator to enable it.';

  /// The module every screen in this app depends on.
  static const List<String> requiredModules = ['stock'];

  /// True if this app's backing module is installed on the connected server.
  ///
  /// A newly-added account may briefly carry a stale company scope from the
  /// previously active account, so the company-scoped probe can report a
  /// false negative. It is retried without company context, and an RPC
  /// failure fails open: `ir.module.module` is not readable by portal users
  /// at all, and a transient or permission failure must not be reported as
  /// a missing module — the portal check that follows catches those users.
  Future<bool> isInventoryModuleInstalled() async {
    final domain = [
      ['name', 'in', requiredModules],
      ['state', '=', 'installed'],
    ];
    final checks = [
      () => OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [domain],
        'kwargs': const {},
      }),
      () => OdooSessionManager.callKwWithCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [domain],
        'kwargs': const {},
      }),
    ];

    bool sawRpcFailure = false;

    for (final check in checks) {
      try {
        final result = await check();
        if ((result is int ? result : 0) > 0) {
          return true;
        }
      } catch (_) {
        sawRpcFailure = true;
      }
    }

    // Only a clean "not found" from every probe counts as missing: a probe
    // that could not be answered must not be mistaken for an absent module.
    if (sawRpcFailure) {
      return true;
    }

    return false;
  }

  /// True when the current user is a portal/public user (`res.users.share`)
  /// and must be refused.
  ///
  /// `share` is a stored field in `SELF_READABLE_FIELDS` on Odoo 17, 18 and
  /// 19, so a portal user can read it on their own record — checking it
  /// directly is reliable on every version, unlike a group lookup.
  Future<bool> isPortalUser() async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId;
      if (userId == null) return false;

      final read = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['share'],
        ],
        'kwargs': const {},
      });
      if (read is List && read.isNotEmpty) {
        final row = read.first;
        if (row is Map && row['share'] == true) {
          return true;
        }
      }
      return false;
    } catch (_) {
      // Fail open: never lock a user out over a transient RPC failure. A
      // genuine denial is re-checked on every login/switch/resume, so it
      // cannot be permanently bypassed by one flaky request.
      return false;
    }
  }
}
