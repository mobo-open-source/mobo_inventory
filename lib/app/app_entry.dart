import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/loaders/loading_indicator.dart';
import '../features/login/pages/server_setup_screen.dart';
import '../features/login/pages/app_lock_screen.dart';
import '../features/login/pages/login_layout.dart' show DatabaseExpiry;
import '../core/services/session_service.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/biometric_context_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/inventory_access_service.dart';
import '../core/utils/module_missing_dialog.dart';
import '../core/routing/app_routes.dart';

class AppEntry extends StatefulWidget {
  final bool skipBiometric;

  const AppEntry({super.key, this.skipBiometric = false});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  Future<Map<String, dynamic>>? _postLoginFuture;
  bool _moduleDialogShown = false;

  @override
  void initState() {
    super.initState();

    ConnectivityService.instance.startMonitoring();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionService>().initialize();
    });
  }

  Future<Map<String, dynamic>> _checkInitialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    bool sessionValid = await OdooSessionManager.isSessionValid();
    bool moduleMissingOnResume = false;

    // A session signed in before its database expired is dropped on the
    // next launch, the same way as a failed module/access check below. Fails
    // open on RPC errors, so being offline never signs anyone out.
    if (sessionValid && await DatabaseExpiry.isCurrentSessionExpired()) {
      await OdooSessionManager.logout();
      sessionValid = false;
      InventoryAccessService.setPendingSignOutMessage(DatabaseExpiry.message);
    }

    if (sessionValid) {
      // Re-validated on every launch, not only at login time: an admin may
      // have uninstalled Inventory or turned this user into a portal user
      // while the session was still active on the device. Both checks fail
      // open on RPC errors, so being offline never signs anyone out.
      final accessService = InventoryAccessService();
      final inventoryInstalled = await accessService
          .isInventoryModuleInstalled();
      final isPortalUser = inventoryInstalled
          ? await accessService.isPortalUser()
          : false;

      if (!inventoryInstalled || isPortalUser) {
        // Undone right here rather than left for a dialog button to do
        // later — otherwise `isLoggedIn` stays true in prefs and every
        // subsequent app start re-hits the same failure forever. Only the
        // active session is dropped; the saved account list is kept.
        await OdooSessionManager.logout();
        sessionValid = false;
        if (!inventoryInstalled) {
          moduleMissingOnResume = true;
        } else {
          InventoryAccessService.setPendingSignOutMessage(
            InventoryAccessService.portalUserMessage,
          );
        }
      }
    }

    return {
      'sessionValid': sessionValid,
      'biometricEnabled': biometricEnabled,
      'hasSeenGetStarted': hasSeenGetStarted,
      'moduleMissingOnResume': moduleMissingOnResume,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = context.watch<SessionService>();

    if (!sessionService.isInitialized) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    _postLoginFuture ??= _checkInitialStatus();

    return FutureBuilder<Map<String, dynamic>>(
      future: _postLoginFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const PopScope(canPop: false, child: ServerSetupScreen());
        }

        final hasSeenGetStarted = snapshot.data!['hasSeenGetStarted'] as bool;
        final sessionValid = snapshot.data!['sessionValid'] as bool;
        final biometricEnabled = snapshot.data!['biometricEnabled'] as bool;
        final moduleMissingOnResume =
            snapshot.data!['moduleMissingOnResume'] as bool? ?? false;

        // The account was already signed out in `_checkInitialStatus` — this
        // dialog is only a notification, so its button just closes it.
        // Checked before the no-session branch below, which would otherwise
        // return the login screen without ever saying why.
        if (moduleMissingOnResume) {
          if (!_moduleDialogShown) {
            _moduleDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showModuleMissingDialog(context, actionLabel: 'OK');
            });
          }
          return const PopScope(canPop: false, child: ServerSetupScreen());
        }

        if (!hasSeenGetStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.goNamed(AppRoutes.getStarted);
            }
          });
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (!sessionService.hasValidSession || !sessionValid) {
          if (_postLoginFuture != null && !sessionService.hasValidSession) {
            _postLoginFuture = null;
          }
          return const PopScope(canPop: false, child: ServerSetupScreen());
        }

        final biometricContext = BiometricContextService();
        final shouldSkipBiometric =
            widget.skipBiometric || biometricContext.shouldSkipBiometric;

        if (biometricEnabled && !shouldSkipBiometric) {
          return PopScope(
            canPop: false,
            child: AppLockScreen(
              onAuthenticationSuccess: () {
                if (!mounted) return;
                context.goNamed(AppRoutes.app, extra: {'skipBiometric': true});
              },
            ),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.goNamed(AppRoutes.dashboard);
            }
          });
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }
      },
    );
  }
}
