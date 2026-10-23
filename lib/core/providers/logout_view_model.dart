import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/session_service.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import '../services/haptics_service.dart';
import '../theme/app_theme.dart';

class LogoutViewModel extends ChangeNotifier {
  // One logout at a time: a double tap on "Log Out" used to run the whole
  // sequence twice, stacking two loading dialogs.
  static bool _inProgress = false;

  Future<void> confirmLogout(BuildContext context) async {
    if (_inProgress) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'Confirm Logout',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to log out? Your session will be ended.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark
                ? Colors.grey[300]
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor, // Outline color
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted && !_inProgress) {
      HapticsService.medium();
      _inProgress = true;
      try {
        await _performLogout(context);
      } finally {
        _inProgress = false;
      }
    }
  }

  /// Everything after the confirmation goes through the root navigator, not
  /// the Profile screen's [context]: clearing the session resets every
  /// provider, which rebuilds (and can unmount) that screen mid-logout. The
  /// old code then skipped the navigation and left the user on a Profile
  /// screen with no account behind it.
  Future<void> _performLogout(BuildContext context) async {
    final sessionService = context.read<SessionService>();
    final reduceMotion = context.read<SettingsProvider>().reduceMotion;
    final rootContext = AppRouter.rootNavigatorKey.currentContext ?? context;
    BuildContext? dialogContext;

    showDialog(
      context: rootContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = isDark
            ? Colors.white
            : Theme.of(context).colorScheme.primary;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Builder(
                      builder: (_) {
                        if (reduceMotion) {
                          return Icon(
                            Icons.hourglass_empty_rounded,
                            color: color,
                            size: 50,
                          );
                        }
                        return LoadingWidget(
                          size: 50,
                          color: color,
                          variant: LoadingVariant.staggeredDots,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Logging out...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Brief pause so the dialog is seen rather than flashing.
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      await sessionService.logout();
    } finally {
      // Close the loading dialog whatever happened; the session is cleared
      // in `logout()`'s own `finally`, so signing out always completes.
      final dc = dialogContext;
      if (dc != null && dc.mounted) Navigator.of(dc).pop();
    }

    // `go` replaces the whole stack (Profile, the shell and anything pushed
    // on it), so Back cannot return to a screen of the signed-out account.
    // The app entry then shows the login screen, or Get Started when needed.
    final navContext = AppRouter.rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    navContext.goNamed(AppRoutes.app);

    Future.delayed(const Duration(milliseconds: 300), () {
      final ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        CustomSnackbar.showSuccess(ctx, 'Logged out successfully');
        HapticsService.success();
      }
    });
  }
}
