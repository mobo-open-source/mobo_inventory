import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/shared_bottom_nav_bar.dart';
import '../shared/widgets/connection_status_banner.dart';
import '../features/profile/providers/profile_provider.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/routing/app_routes.dart';
import '../shared/widgets/app_bar_profile_actions.dart';

class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final List<String> _titles;

  @override
  void initState() {
    super.initState();

    _titles = const [
      'Dashboard',
      'Inventory',
      'Transfer',
      'Replenishment',
      'History',
    ];
    WidgetsBinding.instance.addObserver(this);

    ConnectivityService.instance.startMonitoring();
    OdooSessionManager.getCurrentSession().then((session) {
      ConnectivityService.instance.setCurrentServerUrl(session?.serverUrl);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _validateSession();
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile(forceRefresh: true);
      }
    }
  }

  Future<void> _validateSession() async {
    try {
      final isValid = await OdooSessionManager.isSessionValid();
      if (!isValid && mounted) {
        context.goNamed(AppRoutes.serverSetup);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final selectedIndex = widget.navigationShell.currentIndex;
    final title = _titles[selectedIndex];
    final isReplenishment = selectedIndex == 3;

    return Scaffold(
      appBar: isReplenishment
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: const [AppBarProfileActions()],
              backgroundColor: theme.scaffoldBackgroundColor,
              foregroundColor: isDark ? Colors.white : theme.primaryColor,
              elevation: 0,
              centerTitle: false,
              surfaceTintColor: Colors.transparent,
            ),
      body: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: const ConnectionStatusBanner(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedBottomNavBar(
        navigationShell: widget.navigationShell,
      ),
    );
  }
}
