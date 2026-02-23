import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_entry.dart';
import '../../app/main_shell.dart';
import '../../shared/widgets/splash/splash_screen.dart';
import '../../features/login/pages/server_setup_screen.dart';
import '../../features/login/pages/credentials_screen.dart';
import '../../features/login/pages/add_account_screen.dart';
import '../../features/login/pages/app_lock_screen.dart';
import '../../features/login/pages/reset_password_screen.dart';
import '../../features/onboarding/pages/get_started_screen.dart';
import '../../features/dashboard/pages/dashboard_screen.dart';
import '../../features/inventory/pages/inventory_products_list_screen.dart';
import '../../features/inventory/pages/inventory_product_detail_screen.dart';
import '../../features/replenishment/pages/replenishment_list_screen.dart';
import '../../features/transfer/pages/transfer_list_screen.dart';
import '../../features/transfer/pages/transfer_detail_screen.dart';
import '../../features/transfer/pages/transfer_form_screen.dart';
import '../../features/transfer/models/transfer_model.dart';
import '../../features/adjustment/pages/inventory_adjustment_list_screen.dart';
import '../../features/move_history/pages/move_history_screen.dart';
import '../../features/move_history/pages/move_history_detail_screen.dart';
import '../../features/move_history/models/move_history_item.dart';
import '../../features/profile/pages/profile_screen.dart';
import '../../features/profile/pages/profile_detail_screen.dart';
import '../../features/settings/pages/settings_screen.dart';
import '../../features/inventory/pages/view_stock_screen.dart';
import '../../features/inventory/pages/inventory_product_edit_screen.dart';
import '../../features/inventory/pages/missing_inventory_screen.dart';
import '../../features/warehouse/pages/warehouse_list_screen.dart';
import '../../features/warehouse/pages/warehouse_detail_screen.dart';
import '../../features/warehouse/providers/warehouse_detail_provider.dart';
import '../../shared/widgets/full_image_screen.dart';
import '../../features/locations/pages/location_list_screen.dart';
import '../../features/manufacturing/pages/manufacturing_list_screen.dart';
import '../../features/picking/pages/picking_list_screen.dart';
import '../../shared/widgets/barcode_scanner_screen.dart';
import 'package:provider/provider.dart';
import '../../features/inventory/providers/stock_location_provider.dart';
import '../../features/warehouse/providers/warehouse_provider.dart';
import '../../features/locations/providers/location_provider.dart';
import '../../features/manufacturing/providers/manufacturing_provider.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root_navigator');

  static CustomTransitionPage<T> _buildPageWithSlideTransition<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        var offsetAnimation = animation.drive(tween);

        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  static final GoRouter _router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    errorBuilder: (context, state) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        appBar: AppBar(
          title: const Text('Something went wrong'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: isDark ? Colors.red[300] : Colors.red[700],
                ),
                const SizedBox(height: 16),
                Text(
                  'We navigated to an invalid state. Tap below to return to the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    context.goNamed(AppRoutes.app);
                  },
                  child: const Text('Return to App'),
                ),
              ],
            ),
          ),
        ),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        name: AppRoutes.splash,
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        name: AppRoutes.getStarted,
        path: AppRoutes.getStarted,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: GetStartedScreen()),
      ),
      GoRoute(
        name: AppRoutes.app,
        path: AppRoutes.app,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final skipBiometric =
              (extra is Map && extra['skipBiometric'] == true);
          return NoTransitionPage(
            child: AppEntry(skipBiometric: skipBiometric),
          );
        },
      ),
      GoRoute(
        name: AppRoutes.serverSetup,
        path: AppRoutes.serverSetup,
        pageBuilder: (context, state) {
          bool isAddingAccount = false;
          String? initialUrl;
          String? initialDatabase;
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            isAddingAccount = extra['isAddingAccount'] as bool? ?? false;
            initialUrl = extra['url'] as String?;
            initialDatabase = extra['database'] as String?;
          }
          return NoTransitionPage(
            child: ServerSetupScreen(
              isAddingAccount: isAddingAccount,
              initialUrl: initialUrl,
              initialDatabase: initialDatabase,
            ),
          );
        },
      ),
      GoRoute(
        name: AppRoutes.login,
        path: AppRoutes.login,
        pageBuilder: (context, state) {
          String url = '';
          String database = '';
          bool isAddingAccount = false;
          String? prefilledUsername;
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            url = extra['url'] as String? ?? '';
            database = extra['database'] as String? ?? '';
            isAddingAccount = extra['isAddingAccount'] as bool? ?? false;
            prefilledUsername = extra['prefilledUsername'] as String?;
          }
          return NoTransitionPage(
            key: state.pageKey,
            child: CredentialsScreen(
              url: url,
              database: database,
              isAddingAccount: isAddingAccount,
              prefilledUsername: prefilledUsername,
            ),
          );
        },
      ),
      GoRoute(
        name: AppRoutes.addAccount,
        path: AppRoutes.addAccount,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AddAccountScreen()),
      ),
      GoRoute(
        name: AppRoutes.appLock,
        path: AppRoutes.appLock,
        pageBuilder: (context, state) {
          VoidCallback cb = () {};
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            cb = extra['onAuthenticationSuccess'] as VoidCallback? ?? () {};
          }
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLockScreen(onAuthenticationSuccess: cb),
          );
        },
      ),
      GoRoute(
        name: AppRoutes.resetPassword,
        path: AppRoutes.resetPassword,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: ResetPasswordScreen()),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.dashboard,
                path: AppRoutes.dashboard,
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: const DashboardScreen()),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.inventory,
                path: AppRoutes.inventory,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const InventoryProductsListScreen(),
                ),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.transfer,
                path: AppRoutes.transfer,
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: const TransferListScreen()),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.replenishment,
                path: AppRoutes.replenishment,
                pageBuilder: (context, state) {
                  final args = state.extra as Map<String, dynamic>?;
                  final initialSearchQuery =
                      args?['initialSearchQuery'] as String?;
                  return NoTransitionPage(
                    child: ReplenishmentListScreen(
                      initialSearchQuery: initialSearchQuery,
                    ),
                  );
                },
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRoutes.moveHistory,
                path: AppRoutes.moveHistory,
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: const MoveHistoryScreen()),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        name: AppRoutes.inventoryProductDetail,
        path: AppRoutes.inventoryProductDetail,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final productId = args?['productId'];
          if (productId == null) {
            return _buildPageWithSlideTransition(
              child: const SizedBox.shrink(),
              state: state,
            );
          }
          return _buildPageWithSlideTransition(
            child: InventoryProductDetailScreen(
              productId: int.parse(productId.toString()),
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.transferList,
        path: AppRoutes.transferList,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const TransferListScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.transferDetail,
        path: AppRoutes.transferDetail,
        pageBuilder: (context, state) {
          final extra = state.extra;
          InternalTransfer? transfer;
          if (extra is InternalTransfer) {
            transfer = extra;
          } else if (extra is Map<String, dynamic>) {
            try {
              transfer = InternalTransfer.fromJson(extra);
            } catch (_) {}
          }
          if (transfer == null) {
            return _buildPageWithSlideTransition(
              child: const SizedBox.shrink(),
              state: state,
            );
          }
          return _buildPageWithSlideTransition(
            child: TransferDetailScreen(transfer: transfer),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.transferForm,
        path: AppRoutes.transferForm,
        pageBuilder: (context, state) {
          final extra = state.extra;
          InternalTransfer? transfer;
          if (extra is InternalTransfer) transfer = extra;
          return _buildPageWithSlideTransition(
            child: TransferFormScreen(transfer: transfer),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.adjustment,
        path: AppRoutes.adjustment,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const InventoryAdjustmentListScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.moveHistoryDetail,
        path: AppRoutes.moveHistoryDetail,
        parentNavigatorKey: AppRouter.rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is MoveHistoryItem) {
            return _buildPageWithSlideTransition(
              child: MoveHistoryDetailScreen(item: extra),
              state: state,
            );
          }
          return _buildPageWithSlideTransition(
            child: const SizedBox.shrink(),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.profile,
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const ProfileScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.settings,
        path: AppRoutes.settings,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const SettingsScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.viewStock,
        path: AppRoutes.viewStock,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final productId = args?['productId'] as int? ?? 0;
          final productName = args?['productName'] as String? ?? 'Unknown';
          return _buildPageWithSlideTransition(
            child: ChangeNotifierProvider<StockLocationProvider>(
              create: (_) => StockLocationProvider(),
              child: ViewStockScreen(
                productId: productId,
                productName: productName,
              ),
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.profileDetail,
        path: AppRoutes.profileDetail,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const ProfileDetailScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.inventoryProductEdit,
        path: AppRoutes.inventoryProductEdit,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final productId = args?['productId'];
          if (productId == null) {
            return _buildPageWithSlideTransition(
              child: const SizedBox.shrink(),
              state: state,
            );
          }
          return _buildPageWithSlideTransition(
            child: InventoryProductEditScreen(
              productId: int.parse(productId.toString()),
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.barcodeScanner,
        path: AppRoutes.barcodeScanner,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const BarcodeScannerScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.warehouseList,
        path: AppRoutes.warehouseList,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: ChangeNotifierProvider(
            create: (_) => WarehouseProvider(),
            child: const WarehouseListScreen(),
          ),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.warehouseDetail,
        path: AppRoutes.warehouseDetail,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final warehouseId = args?['warehouseId'] as int?;
          if (warehouseId == null) {
            return _buildPageWithSlideTransition(
              child: const SizedBox.shrink(),
              state: state,
            );
          }
          return _buildPageWithSlideTransition(
            child: ChangeNotifierProvider(
              create: (_) => WarehouseDetailProvider(),
              child: WarehouseDetailScreen(warehouseId: warehouseId),
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.locationList,
        path: AppRoutes.locationList,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final title = args?['title'] as String? ?? 'Locations';
          return _buildPageWithSlideTransition(
            child: ChangeNotifierProvider(
              create: (_) => LocationProvider(),
              child: LocationListScreen(title: title),
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.manufacturingList,
        path: AppRoutes.manufacturingList,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: ChangeNotifierProvider(
            create: (_) => ManufacturingProvider(),
            child: const ManufacturingListScreen(),
          ),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.deliveryList,
        path: AppRoutes.deliveryList,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const DeliveryListScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.receiptList,
        path: AppRoutes.receiptList,
        pageBuilder: (context, state) => _buildPageWithSlideTransition(
          child: const ReceiptListScreen(),
          state: state,
        ),
      ),
      GoRoute(
        name: AppRoutes.missingInventory,
        path: AppRoutes.missingInventory,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final onRetry = args?['onRetry'] as VoidCallback? ?? () {};
          return _buildPageWithSlideTransition(
            child: MissingInventoryScreen(onRetry: onRetry),
            state: state,
          );
        },
      ),
      GoRoute(
        name: AppRoutes.fullImage,
        path: AppRoutes.fullImage,
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final imageBytes = args?['imageBytes'] as Uint8List?;
          final title = args?['title'] as String?;
          if (imageBytes == null) {
            return _buildPageWithSlideTransition(
              child: const SizedBox.shrink(),
              state: state,
            );
          }
          return _buildPageWithSlideTransition(
            child: FullImageScreen(imageBytes: imageBytes, title: title ?? ''),
            state: state,
          );
        },
      ),
    ],
  );

  static GoRouter build() {
    return _router;
  }
}
