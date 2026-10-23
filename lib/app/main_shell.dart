import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/shared_bottom_nav_bar.dart';
import '../shared/widgets/global_network_banner.dart';
import '../shared/widgets/layout/collapsible_header_layout.dart';
import '../core/services/access_rights_service.dart';
import '../features/profile/providers/profile_provider.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/routing/app_routes.dart';
import '../shared/widgets/app_bar_profile_actions.dart';
import '../core/services/review_service.dart';
import '../main.dart';

class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  /// AppBar titles, indexed by shell branch — the same indices as
  /// [AccessRightsService]'s branch constants, whichever tabs are visible.
  static const List<String> _titles = [
    'Dashboard',
    'Inventory',
    'Transfer',
    'Replenishment',
    'History',
  ];

  /// App bar height on a short (landscape phone) screen; the default 56
  /// elsewhere.
  static const double _compactToolbarHeight = 48;

  final AccessRightsService _access = AccessRightsService.instance;
  bool _branchFixScheduled = false;

  @override
  void initState() {
    super.initState();
    assert(_titles.length == AccessRightsService.branchCount);

    WidgetsBinding.instance.addObserver(this);
    _access.addListener(_onAccessChanged);
    _keepOnAllowedBranch();

    OdooSessionManager.getCurrentSession().then((session) {
      ConnectivityService.instance.setCurrentServerUrl(session?.serverUrl);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile();
      }
      _access.ensureLoaded();

      // Use a slightly longer delay to ensure the UI and navigator are fully ready
      Future.delayed(const Duration(seconds: 3), () {
        ReviewService().trackAppOpen();

        // Use the stable navigator context instead of the local one which might unmount
        final targetContext = navigatorKey.currentContext;
        if (targetContext != null && targetContext.mounted) {
          ReviewService().checkAndShowRating(targetContext);
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Navigation (a dashboard card, a deep link) may land on a hidden tab.
    _keepOnAllowedBranch();
  }

  @override
  void dispose() {
    _access.removeListener(_onAccessChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAccessChanged() {
    if (!mounted) return;
    setState(() {});
    _keepOnAllowedBranch();
  }

  /// Moves off the current branch once the user's access rights no longer
  /// allow it, to the first branch they do (Dashboard is always allowed).
  /// After the frame: switching branches notifies the router, which must not
  /// happen during a build.
  void _keepOnAllowedBranch() {
    if (_branchFixScheduled) return;
    final current = widget.navigationShell.currentIndex;
    if (AccessRightsService.resolveBranch(current, _access.visibleBranches) ==
        current) {
      return;
    }
    _branchFixScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _branchFixScheduled = false;
      if (!mounted) return;
      final now = widget.navigationShell.currentIndex;
      final target = AccessRightsService.resolveBranch(
        now,
        _access.visibleBranches,
      );
      if (target != now) widget.navigationShell.goBranch(target);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _validateSession();
      // Rights changed in Odoo while the app was in the background show up
      // without a relaunch.
      _access.refresh();
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile();
      }
    }
  }

  Future<void> _validateSession() async {
    try {
      final isValid = await OdooSessionManager.isSessionValid();
      if (!isValid && mounted) {
        context.goNamed(AppRoutes.serverSetup);
      }
    } catch (_) {
      // Unreadable prefs: keep the current session rather than sign out.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final selectedIndex = widget.navigationShell.currentIndex;
    final title = _titles[selectedIndex];
    final isReplenishment =
        selectedIndex == AccessRightsService.replenishmentBranch;
    final visibleBranches = _access.visibleBranches;
    final compact = isCompactHeight(context);

    return BackToDashboardScope(
      navigationShell: widget.navigationShell,
      child: Scaffold(
        appBar: isReplenishment
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: compact ? _compactToolbarHeight : null,
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
        body: widget.navigationShell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlobalNetworkBanner(),
            // A bar with Dashboard alone would offer nothing to switch to.
            if (visibleBranches.length > 1)
              SharedBottomNavBar(
                navigationShell: widget.navigationShell,
                visibleBranches: visibleBranches,
                compact: compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// Back on any tab but the Dashboard returns to the Dashboard instead of
/// closing the app: switching tabs leaves nothing on the back stack. A page
/// opened inside a tab is popped first — go_router asks the tab's own
/// navigator before this one.
class BackToDashboardScope extends StatelessWidget {
  const BackToDashboardScope({
    super.key,
    required this.navigationShell,
    required this.child,
  });

  final StatefulNavigationShell navigationShell;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          navigationShell.currentIndex == AccessRightsService.dashboardBranch,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        navigationShell.goBranch(AccessRightsService.dashboardBranch);
      },
      child: child,
    );
  }
}
