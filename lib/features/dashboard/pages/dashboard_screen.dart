import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/base64_utils.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/recent_items_widget.dart';
import '../providers/last_opened_provider.dart';
import '../widgets/dashboard_greeting_card.dart';
import '../widgets/dashboard_stats_shimmer.dart';
import '../widgets/recent_activities_list.dart';
import '../widgets/negative_quants_list.dart';
import '../widgets/today_activities_list.dart';
import '../widgets/operations_today_summary.dart';
import '../widgets/replenishment_needs_list.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/user_cache_service.dart';
import '../../../core/routing/app_routes.dart';
import '../../replenishment/providers/replenishment_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/connection_status_widget.dart';
import '../../../shared/widgets/empty_state.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DashboardProvider>();
      _fetchData(provider);
    });
  }

  void _fetchData(DashboardProvider provider) {
    provider.fetchStats();
    provider.fetchRecentActivities(limit: 4);
    provider.fetchNegativeQuants(limit: 4);
    provider.fetchTodayActivities(limit: 4);
    provider.fetchTodayOperationsCounts();
    provider.fetchReplenishmentNeeds(limit: 4);
    provider.fetchUserInfo();
  }

  Future<void> _onRefresh() async {
    final provider = context.read<DashboardProvider>();
    await Future.wait([
      provider.fetchStats(forceRefresh: true),
      provider.fetchTodayOperationsCounts(),
      provider.fetchReplenishmentNeeds(limit: 4),
      provider.fetchNegativeQuants(limit: 4),
      provider.fetchTodayActivities(limit: 4),
      provider.fetchRecentActivities(limit: 4),
      provider.fetchUserInfo(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final sessionService = context.watch<SessionService>();

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            color: theme.primaryColor,
            child: _buildBody(isDark, theme, provider),
          ),
        );
      },
    );
  }

  Widget _buildBody(bool isDark, ThemeData theme, DashboardProvider provider) {
    if (provider.error != null &&
        !provider.hasLoadedData &&
        !provider.isLoading) {
      final err = provider.error!.toLowerCase();
      final isModuleNotInstalled =
          err.contains('module') && err.contains('not installed');
      final title = isModuleNotInstalled
          ? 'Feature unavailable'
          : 'Something went wrong';
      final subtitle = isModuleNotInstalled
          ? 'This module is not installed on your server. Please contact your administrator.'
          : 'Pull to refresh or tap retry';
      final lottiePath = isModuleNotInstalled
          ? 'assets/lotties/socialv no data.json'
          : 'assets/lotties/Error 404.json';

      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyState(
                title: title,
                subtitle: subtitle,
                lottieAsset: lottiePath,
                actionLabel: 'Retry',
                onAction: () => provider.fetchStats(forceRefresh: true),
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
              userName: provider.userName,
              userAvatar: provider.userAvatarBase64,
              isLoading: true,
            ),
          ),
          SliverToBoxAdapter(child: const DashboardStatsShimmer()),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardGreetingCard(
            userName: provider.userName,
            userAvatar: provider.userAvatarBase64,
            isLoading: provider.isLoadingUser,
            isOffline:
                provider.error != null &&
                (provider.error!.toLowerCase().contains('offline') ||
                    provider.error!.toLowerCase().contains('no internet') ||
                    provider.error!.toLowerCase().contains('network')),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;

              int crossAxisCount;
              if (width >= 1000) {
                crossAxisCount = 4;
              } else if (width >= 600) {
                crossAxisCount = 3;
              } else {
                crossAxisCount = 2;
              }

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate([
                  DashboardStatCard(
                    title: 'Total Warehouses',
                    count: provider.stats.totalWarehouses.toString(),
                    icon: HugeIcons.strokeRoundedWarehouse,
                    color: theme.primaryColor,
                    subtitle: 'manage your company warehouse',
                    onTap: () {
                      context.pushNamed(AppRoutes.warehouseList);
                    },
                  ),
                  DashboardStatCard(
                    title: 'Locations',
                    count: provider.stats.totalLocations.toString(),
                    icon: HugeIcons.strokeRoundedLocation01,
                    color: Colors.blue,
                    subtitle: 'manage warehouse locations',
                    onTap: () {
                      context.pushNamed(
                        AppRoutes.locationList,
                        extra: {'title': 'Locations'},
                      );
                    },
                  ),
                  DashboardStatCard(
                    title: 'Delivery Orders',
                    count: provider.stats.deliveryOrders.toString(),
                    subtitle: '${provider.stats.readyToDeliver} Ready',
                    icon: HugeIcons.strokeRoundedDeliveryTruck01,
                    color: Colors.orange,
                    onTap: () {
                      context.pushNamed(AppRoutes.deliveryList);
                    },
                  ),
                  DashboardStatCard(
                    title: 'Receipts',
                    count: provider.stats.receipts.toString(),
                    subtitle: '${provider.stats.readyToReceive} Ready',
                    icon: HugeIcons.strokeRoundedPackageReceive,
                    color: Colors.green,
                    onTap: () {
                      context.pushNamed(AppRoutes.receiptList);
                    },
                  ),
                  DashboardStatCard(
                    title: 'Internal Transfers',
                    count: provider.stats.internalTransfers.toString(),
                    subtitle: '${provider.stats.readyToTransfer} Ready',
                    icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
                    color: Colors.purple,
                    onTap: () {
                      context.goNamed(AppRoutes.transfer);
                    },
                  ),
                  DashboardStatCard(
                    title: 'Manufacturing Orders',
                    count: provider.stats.manufacturingOrders.toString(),
                    subtitle: '${provider.stats.readyToProduce} Ready',
                    icon: HugeIcons.strokeRoundedFactory,
                    color: Colors.teal,
                    onTap: () {
                      context.pushNamed(AppRoutes.manufacturingList);
                    },
                  ),
                ]),
              );
            },
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Consumer<LastOpenedProvider>(
              builder: (context, lastOpenedProvider, _) {
                return RecentItemsWidget(
                  recentItems: lastOpenedProvider.items,
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

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: OperationsTodaySummary(
              incomingCount: provider.incomingToday,
              outgoingCount: provider.outgoingToday,
              isLoading: provider.isLoadingOpsToday,
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: ReplenishmentNeedsList(
              items: provider.replenishmentNeeds,
              isLoading: provider.isLoadingReplenishment,
              onSeeAll: null,
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: NegativeQuantsList(
              items: provider.negativeQuants,
              isLoading: provider.isLoadingNegative,
              onSeeAll: null,
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: TodayActivitiesList(
              items: provider.todayActivities,
              isLoading: provider.isLoadingToday,
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}
