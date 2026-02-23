import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/inventory/providers/inventory_product_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/providers/last_opened_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/transfer/providers/transfer_provider.dart';
import 'features/adjustment/providers/adjustment_provider.dart';
import 'features/move_history/providers/move_history_provider.dart';
import 'features/company/providers/company_provider.dart';
import 'features/replenishment/providers/replenishment_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/session_service.dart';
import 'shared/widgets/connectivity_listener_widget.dart';
import 'core/routing/app_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProductProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
        ChangeNotifierProvider(create: (_) => AdjustmentProvider()),
        ChangeNotifierProvider(create: (_) => MoveHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ReplenishmentProvider()),
        ChangeNotifierProvider(create: (_) => LastOpenedProvider()),

        ChangeNotifierProvider<SessionService>.value(
          value: SessionService.instance,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// The root widget of the application, responsible for configuring the theme, routing, and global connectivity monitoring.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ConnectivityListenerWidget(
          child: MaterialApp.router(
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            title: 'Mobo Inv App',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.build(),
          ),
        );
      },
    );
  }
}
