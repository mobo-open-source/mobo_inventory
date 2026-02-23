import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/loaders/loading_indicator.dart';
import '../features/login/pages/server_setup_screen.dart';
import '../features/login/pages/app_lock_screen.dart';
import '../core/services/session_service.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/biometric_context_service.dart';
import '../core/services/connectivity_service.dart';
import '../features/inventory/pages/missing_inventory_screen.dart';
import '../core/routing/app_routes.dart';

class AppEntry extends StatefulWidget {
  final bool skipBiometric;

  const AppEntry({super.key, this.skipBiometric = false});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  Future<Map<String, dynamic>>? _postLoginFuture;

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

    bool inventoryInstalled = prefs.getBool('inventory_installed') ?? false;

    if (sessionValid) {
      try {
        final count = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'ir.module.module',
          'method': 'search_count',
          'args': [
            [
              ['name', '=', 'stock'],
              ['state', '=', 'installed'],
            ],
          ],
          'kwargs': {},
        });
        final isInstalled = (count is int) ? count > 0 : (count as num) > 0;

        if (isInstalled != inventoryInstalled) {
          inventoryInstalled = isInstalled;
          await prefs.setBool('inventory_installed', isInstalled);
        }
      } catch (e) {
        if (!inventoryInstalled) {
          inventoryInstalled = true;
        }
      }
    }

    return {
      'sessionValid': sessionValid,
      'biometricEnabled': biometricEnabled,
      'inventoryInstalled': inventoryInstalled,
      'hasSeenGetStarted': hasSeenGetStarted,
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
        final inventoryInstalled =
            snapshot.data!['inventoryInstalled'] as bool? ?? false;

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
          if (!inventoryInstalled) {
            return PopScope(
              canPop: false,
              child: MissingInventoryScreen(
                onRetry: () {
                  setState(() {
                    _postLoginFuture = null;
                  });
                },
              ),
            );
          }

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
