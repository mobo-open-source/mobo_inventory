import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/logout_view_model.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/services/session_service.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';

/// Error screen displayed when the inventory module is not found on the Odoo server.
class MissingInventoryScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const MissingInventoryScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isTablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

            final maxWidth = isMobile
                ? double.infinity
                : isTablet
                ? 520.0
                : 600.0;

            final animationHeight = isMobile
                ? 160.0
                : isTablet
                ? 200.0
                : 220.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: animationHeight,
                        child: Lottie.asset(
                          'assets/lotties/socialv no data.json',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Inventory module not installed',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Please install the Inventory module on your Odoo server and try again.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              if (HapticsService.isSupported) {
                                await HapticsService.selection();
                              }
                              onRetry();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(140, 44),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (HapticsService.isSupported) {
                                await HapticsService.selection();
                              }
                              if (!context.mounted) return;

                              try {
                                final vm = context.read<LogoutViewModel>();
                                await vm.confirmLogout(context);
                              } catch (_) {
                                await SessionService.instance.logout();
                                if (context.mounted) {
                                  context.goNamed(AppRoutes.app);
                                }
                              }
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(140, 44),
                              backgroundColor: isDark
                                  ? Colors.red[700]
                                  : theme.colorScheme.error,
                              foregroundColor: isDark
                                  ? Colors.white
                                  : theme.colorScheme.onError,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
