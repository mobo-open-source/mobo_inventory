import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/recent_items_widget.dart';
import '../providers/last_opened_provider.dart';
import '../widgets/dashboard_greeting_card.dart';
import '../widgets/dashboard_stats_shimmer.dart';
import '../widgets/negative_quants_list.dart';
import '../widgets/today_activities_list.dart';
import '../widgets/operations_today_summary.dart';
import '../widgets/replenishment_needs_list.dart';
import '../../../core/routing/app_routes.dart';
import '../../profile/providers/profile_provider.dart';
import '../../company/providers/company_provider.dart';
import '../../replenishment/providers/replenishment_provider.dart';
import '../../../core/services/access_rights_service.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/error_manager.dart';

/// Main dashboard screen providing a business overview with key metrics and activities.
/// The main dashboard screen providing a comprehensive overview of inventory operations.
///
/// Displays key performance indicators, recent activities, negative quant alerts,
/// and replenishment needs. It serves as the primary entry point for the application.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Vertical gap between dashboard sections; each section's heading sits
  /// 12px above its content.
  static const double _sectionGap = 24;

  late final CompanyProvider _companyProvider;
  late final AccessRightsService _access;

  /// The company scope the dashboard last loaded for (see [_scopeOf]).
  String? _companyScope;

  /// Models the dashboard reads, and those Odoo said the user may not.
  static const List<String> _readModels = [
    'stock.warehouse',
    'stock.location',
    'stock.picking',
    'stock.quant',
    'mrp.production',
    'stock.warehouse.orderpoint',
  ];
  Set<String> _unreadable = const {};

  @override
  void initState() {
    super.initState();
    _companyProvider = context.read<CompanyProvider>();
    _companyScope = _scopeOf(_companyProvider);
    _companyProvider.addListener(_onCompanyChanged);
    _access = context.read<AccessRightsService>();
    _unreadable = _unreadableModels();
    _access.addListener(_onAccessChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DashboardProvider>();
      _fetchData(provider);
    });
  }

  @override
  void dispose() {
    _companyProvider.removeListener(_onCompanyChanged);
    _access.removeListener(_onAccessChanged);
    super.dispose();
  }

  Set<String> _unreadableModels() => {
    for (final model in _readModels)
      if (!_access.can(model, 'read')) model,
  };

  /// Loads again when a model the dashboard skipped (the user could not
  /// read it) becomes readable — rights granted in Odoo show up on the next
  /// access refresh, e.g. when the app returns to the foreground. Losing a
  /// right needs no reload: the cards for it are hidden on rebuild.
  void _onAccessChanged() {
    if (!mounted) return;
    final unreadable = _unreadableModels();
    final regained = _unreadable.difference(unreadable);
    _unreadable = unreadable;
    if (regained.isNotEmpty) context.read<DashboardProvider>().refreshAll();
  }

  /// The selected and allowed companies every dashboard RPC runs in, or
  /// null while there is no selection (signed out, or not loaded yet).
  static String? _scopeOf(CompanyProvider company) {
    final selected = company.selectedCompanyId;
    if (selected == null) return null;
    final allowed = [...company.selectedAllowedCompanyIds]..sort();
    return '$selected:${allowed.join(',')}';
  }

  /// Loads everything again once the company scope settles on a new value.
  ///
  /// Every count is taken in the session's company scope at the moment it
  /// is sent. Right after sign-in the company list settles a moment after
  /// the dashboard's own first load has gone out — still scoped to every
  /// company the user may access — so the tiles showed, e.g., all three
  /// warehouses and every company's deliveries instead of the selected
  /// company's. Opening the company picker re-reads the companies too, and
  /// can narrow the allowed ones the same way.
  void _onCompanyChanged() {
    if (!mounted) return;
    if (_companyProvider.isLoading || _companyProvider.isSwitching) return;
    final scope = _scopeOf(_companyProvider);
    if (scope == _companyScope) return;
    _companyScope = scope;
    if (scope == null) return;
    context.read<DashboardProvider>().refreshAll();
  }

  void _fetchData(DashboardProvider provider) {
    provider.fetchStats();
    provider.fetchRecentActivities(limit: 4);
    provider.fetchNegativeQuants(limit: 4);
    provider.fetchTodayActivities(limit: 4);
    provider.fetchTodayOperationsCounts();
    provider.fetchReplenishmentNeeds(limit: 4);
    context.read<ProfileProvider>().fetchUserProfile();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<DashboardProvider>().refreshAll(),
      _retryProfileAndCompany(),
    ]);
  }

  /// Retries the AppBar's shared profile avatar and company selector too —
  /// both only ever fetch once at app start, so a failed initial load (e.g.
  /// the server being unreachable) otherwise leaves them permanently stuck
  /// with no data, with no relation to whether the dashboard itself recovers.
  Future<void> _retryProfileAndCompany() async {
    final profile = context.read<ProfileProvider>();
    final futures = <Future<void>>[profile.fetchUserProfile()];
    final company = context.read<CompanyProvider>();
    if (company.companies.isEmpty) {
      futures.add(company.initialize());
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    context.watch<SessionService>();
    // Rebuild when Odoo's answers about the user's rights arrive.
    context.watch<AccessRightsService>();

    return Consumer2<DashboardProvider, ProfileProvider>(
      builder: (context, provider, profile, child) {
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            color: theme.primaryColor,
            child: _buildBody(isDark, theme, provider, profile),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    bool isDark,
    ThemeData theme,
    DashboardProvider provider,
    ProfileProvider profile,
  ) {
    if (provider.error != null &&
        !provider.hasLoadedData &&
        !provider.isLoading) {
      final info = ErrorManager.analyzeError(provider.error!);
      final lottiePath = info.type == ErrorType.moduleNotInstalled
          ? 'assets/lotties/socialv no data.json'
          : 'assets/lotties/Error 404.json';

      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyState(
                title: info.title,
                subtitle: info.message,
                lottieAsset: lottiePath,
                actionLabel: 'Retry',
                onAction: () {
                  provider.fetchStats(forceRefresh: true);
                  _retryProfileAndCompany();
                },
              ),
            ),
          ),
        ],
      );
    }

    if (provider.isLoading || !provider.hasLoadedData) {
      // Auto-fetch if data is missing and not loading
      if (!provider.isLoading && provider.error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchData(provider);
        });
      }

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DashboardGreetingCard(
              userName: profile.userData?['name']?.toString(),
              userAvatar: profile.userAvatarBase64,
              isLoading: true,
            ),
          ),
          SliverToBoxAdapter(child: const DashboardStatsShimmer()),
        ],
      );
    }

    // Each card only for users who may read what it counts — a user
    // without Inventory rights has the Dashboard as their only tab.
    final stats = provider.stats;
    final canReadPickings =
        stats.showPickings && _access.can('stock.picking', 'read');
    final statCards = <Widget>[
      if (stats.showWarehouses && _access.can('stock.warehouse', 'read'))
        DashboardStatCard(
          title: 'Total Warehouses',
          count: stats.totalWarehouses.toString(),
          icon: HugeIcons.strokeRoundedWarehouse,
          color: theme.primaryColor,
          subtitle: 'manage your company warehouse',
          onTap: () => context.pushNamed(AppRoutes.warehouseList),
        ),
      // Odoo only has a Locations menu with its "Storage Locations" setting
      // on.
      if (stats.showLocations && _access.can('stock.location', 'read'))
        DashboardStatCard(
          title: 'Locations',
          count: stats.totalLocations.toString(),
          icon: HugeIcons.strokeRoundedLocation01,
          color: StatusColors.blue,
          subtitle: 'manage warehouse locations',
          onTap: () => context.pushNamed(
            AppRoutes.locationList,
            extra: {'title': 'Locations'},
          ),
        ),
      if (canReadPickings) ...[
        DashboardStatCard(
          title: 'Delivery Orders',
          count: stats.deliveryOrders.toString(),
          subtitle: 'To Process',
          icon: HugeIcons.strokeRoundedDeliveryTruck01,
          color: StatusColors.orange,
          onTap: () => context.pushNamed(AppRoutes.deliveryList),
        ),
        DashboardStatCard(
          title: 'Receipts',
          count: stats.receipts.toString(),
          subtitle: 'To Process',
          icon: HugeIcons.strokeRoundedPackageReceive,
          color: StatusColors.green,
          onTap: () => context.pushNamed(AppRoutes.receiptList),
        ),
        DashboardStatCard(
          title: 'Internal Transfers',
          count: stats.internalTransfers.toString(),
          subtitle: 'To Process',
          icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
          color: theme.primaryColor,
          onTap: () => context.pushNamed(AppRoutes.internalTransferList),
        ),
        // Point of Sale's pickings, apart from Delivery Orders as in Odoo's
        // Inventory Overview; only with Point of Sale installed.
        if (stats.showPosOrders)
          DashboardStatCard(
            title: 'PoS Orders',
            count: stats.posOrders.toString(),
            subtitle: 'To Process',
            icon: HugeIcons.strokeRoundedCashier,
            color: StatusColors.blue,
            onTap: () => context.pushNamed(AppRoutes.posOrderList),
          ),
      ],
      // Only with the Manufacturing (`mrp`) module installed.
      if (stats.showManufacturing && _access.can('mrp.production', 'read'))
        DashboardStatCard(
          title: 'Manufacturing Orders',
          count: stats.manufacturingOrders.toString(),
          subtitle: '${stats.readyToProduce} Ready',
          icon: HugeIcons.strokeRoundedFactory,
          color: StatusColors.green,
          onTap: () => context.pushNamed(AppRoutes.manufacturingList),
        ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardGreetingCard(
            userName: profile.userData?['name']?.toString(),
            userAvatar: profile.userAvatarBase64,
            isLoading: profile.isLoading,
            isOffline:
                provider.error != null &&
                (provider.error!.toLowerCase().contains('offline') ||
                    provider.error!.toLowerCase().contains('no internet') ||
                    provider.error!.toLowerCase().contains('network')),
          ),
        ),

        if (statCards.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Key metrics at a glance',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                return SliverGrid(
                  gridDelegate: DashboardStatCard.gridDelegate(
                    context,
                    constraints.crossAxisExtent,
                    itemCount: statCards.length,
                  ),
                  delegate: SliverChildListDelegate(statCards),
                );
              },
            ),
          ),
        ],

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, _sectionGap, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Consumer<LastOpenedProvider>(
              builder: (context, lastOpenedProvider, _) {
                return RecentItemsWidget(
                  // Only items the user may still open.
                  recentItems: lastOpenedProvider.items
                      .where((item) => item.canOpen(_access))
                      .toList(),
                  isLoading: false,
                  isDark: isDark,
                  onItemTap: (item) {
                    if (item.route == AppRoutes.replenishment) {
                      final searchQuery =
                          item.data?['initialSearchQuery'] as String?;
                      if (searchQuery != null) {
                        context.read<ReplenishmentProvider>().fetch(
                          searchQuery: searchQuery,
                          forceRefresh: true,
                        );
                      }

                      context.goNamed(AppRoutes.replenishment);
                    } else {
                      context.pushNamed(item.route, extra: item.data);
                    }
                  },
                );
              },
            ),
          ),
        ),

        if (canReadPickings)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, _sectionGap, 16, 0),
            sliver: SliverToBoxAdapter(
              child: OperationsTodaySummary(
                incomingCount: provider.incomingToday,
                outgoingCount: provider.outgoingToday,
                isLoading: provider.isLoadingOpsToday,
              ),
            ),
          ),

        if (_access.can('stock.warehouse.orderpoint', 'read'))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, _sectionGap, 16, 0),
            sliver: SliverToBoxAdapter(
              child: ReplenishmentNeedsList(
                items: provider.replenishmentNeeds,
                isLoading: provider.isLoadingReplenishment,
                // No "See all": it would open the Replenish tab, which needs
                // `isBranchVisible(replenishmentBranch)` if ever added.
                onSeeAll: null,
              ),
            ),
          ),

        if (_access.can('stock.quant', 'read'))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, _sectionGap, 16, 0),
            sliver: SliverToBoxAdapter(
              child: NegativeQuantsList(
                items: provider.negativeQuants,
                isLoading: provider.isLoadingNegative,
                onSeeAll: null,
              ),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, _sectionGap, 16, 0),
          sliver: SliverToBoxAdapter(
            child: TodayActivitiesList(
              items: provider.todayActivities,
              isLoading: provider.isLoadingToday,
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: _sectionGap)),
      ],
    );
  }
}
