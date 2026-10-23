import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'odoo_session_manager.dart';
import 'session_service.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import '../../shared/widgets/dialogs/common_dialog.dart';

/// Shows a blocking "please log in again" dialog when a silent
/// re-authentication attempt (using the password stored for the current
/// session) has been rejected by the server — i.e. the session has actually
/// expired and the cached credentials no longer work, so a fresh login is
/// unavoidable.
class SessionExpiryHandler {
  SessionExpiryHandler._();

  static bool _isDialogShowing = false;

  static void init() {
    OdooSessionManager.setSessionExpiredCallback(_show);
  }

  static void _show() {
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null || _isDialogShowing) return;
    _isDialogShowing = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: CommonDialog(
          title: 'Session Expired',
          message: 'Your session has expired. Please log in again to continue.',
          icon: Icons.lock_clock_outlined,
          destructivePrimary: true,
          primaryLabel: 'Log In Again',
          onPrimary: () => _logout(dialogContext),
        ),
      ),
    ).whenComplete(() => _isDialogShowing = false);
  }

  /// Replicates the exact logout sequence used by the Profile screen's
  /// Logout button (`SessionService.logout()`), then sends the user straight
  /// to the server-setup/login screen. Also resets the app-wide Dashboard
  /// and Company providers — they are top-level singletons that otherwise
  /// keep showing their last (session-expired) error after logging back in,
  /// since they are never rebuilt/disposed by route navigation alone.
  static Future<void> _logout(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();

    await SessionService.instance.logout();

    final context = AppRouter.rootNavigatorKey.currentContext;
    // Every account-scoped provider is reset by AccountChangeListener when
    // the logout above clears the session.
    if (context != null && context.mounted) {
      context.goNamed(AppRoutes.serverSetup);
    }
  }
}
