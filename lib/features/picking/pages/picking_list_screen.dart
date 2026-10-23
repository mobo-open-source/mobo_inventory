import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/picking_provider.dart';
import '../services/picking_service.dart';
import '../widgets/picking_list_tile.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/error_manager.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/connection_status_widget.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';

/// A generic screen for displaying various types of stock pickings (Receipts, Deliveries, etc.).
///
/// Features search, advanced filtering by status and date range, and grouped
/// views to streamline stock movements and picking operations.
class PickingListScreen extends StatefulWidget {
  final String title;
  final String pickingTypeCode;

  const PickingListScreen({
    super.key,
    required this.title,
    required this.pickingTypeCode,
  });

  @override
  State<PickingListScreen> createState() => _PickingListScreenState();
}

class _PickingListScreenState extends State<PickingListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);
  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PickingProvider>();
      provider.fetchPickings();
      if (provider.selectedGroupBy != null) {
        provider.fetchGroupSummary();
      }
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (!mounted) return;
      context.read<PickingProvider>().fetchPickings(
        searchQuery: _searchController.text.trim(),
        forceRefresh: true,
      );
      HapticsService.light();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<PickingProvider>().fetchPickings(forceRefresh: true);
  }

  void _clearAllFilters() {
    _searchController.clear();
    final provider = context.read<PickingProvider>();
    provider.clearFilters();
    provider.fetchPickings(forceRefresh: true);
  }

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilterBottomSheet() {
    final provider = context.read<PickingProvider>();

    final statusGroup = FilterGroup(
      title: 'Status',
      options: [
        FilterOption(title: 'Draft', value: provider.states.contains('draft')),
        FilterOption(
          title: 'Waiting',
          value: provider.states.contains('confirmed'),
        ),
        FilterOption(
          title: 'Waiting Another Operation',
          value: provider.states.contains('waiting'),
        ),
        FilterOption(
          title: 'Ready',
          value: provider.states.contains('assigned'),
        ),
        FilterOption(title: 'Done', value: provider.states.contains('done')),
        FilterOption(
          title: 'Cancelled',
          value: provider.states.contains('cancel'),
        ),
      ],
    );

    final dateRangeGroup = FilterGroup(
      title: 'Date Range',
      options: [
        FilterOption(
          title: 'Start Date',
          value: provider.startDate != null,
          selectedValue: provider.startDate,
        ),
        FilterOption(
          title: 'End Date',
          value: provider.endDate != null,
          selectedValue: provider.endDate,
        ),
      ],
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: [
        FilterOption(
          title: 'Status',
          subtitle: 'Group by picking status',
          value: provider.selectedGroupBy == 'state',
        ),
        FilterOption(
          title: 'Date',
          subtitle: 'Group by scheduled date',
          value: provider.selectedGroupBy == 'scheduled_date',
        ),
        FilterOption(
          title: 'Priority',
          subtitle: 'Group by normal or urgent',
          value: provider.selectedGroupBy == 'priority',
        ),
      ],
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [statusGroup, dateRangeGroup],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        final states = <String>[];
        if (values['status_draft'] == true) states.add('draft');
        if (values['status_waiting'] == true) states.add('confirmed');
        if (values['status_waiting_another_operation'] == true) {
          states.add('waiting');
        }
        if (values['status_ready'] == true) states.add('assigned');
        if (values['status_done'] == true) states.add('done');
        if (values['status_cancelled'] == true) states.add('cancel');

        final startDate = values['date_range_start_date_value'] as DateTime?;
        final endDate = values['date_range_end_date_value'] as DateTime?;

        String? groupBy;
        for (final entry in {
          'state': 'status',
          'scheduled_date': 'date',
          'priority': 'priority',
        }.entries) {
          if (values['group_by_${_snake(entry.value)}'] == true) {
            groupBy = entry.key;
            break;
          }
        }

        provider.setGroupBy(groupBy);
        provider.fetchPickings(
          states: states,
          startDate: startDate,
          endDate: endDate,
        );
        if (groupBy != null) {
          provider.fetchGroupSummary();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final sessionService = context.watch<SessionService>();
    final pickingProvider = context.watch<PickingProvider>();

    if (sessionService.isServerUnreachable) {
      return Scaffold(
        body: ConnectionStatusWidget(
          serverUnreachable: true,
          onRetry: () async {
            await sessionService.checkConnectivity();
            if (!sessionService.isServerUnreachable && mounted) {
              context.read<PickingProvider>().fetchPickings(forceRefresh: true);
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // On a short screen (a phone in landscape) the search bar and filter
      // row scroll away with the list instead of staying pinned over it.
      body: CollapsibleHeaderLayout(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: MoboSearchFilterBar(
                controller: _searchController,
                hintText: 'Search ${widget.title.toLowerCase()}...',
                hasActiveFilter: _activeFilterCount(pickingProvider) > 0,
                onFilterTap: _showFilterBottomSheet,
                onChanged: (_) => setState(() {}),
              ),
            ),

            Consumer<PickingProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildActiveFiltersBadge(provider, theme),
                              if (provider.selectedGroupBy != null) ...[
                                const SizedBox(width: 8),
                                _buildGroupByPill(provider, theme),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // A grouped list pages its groups, as Odoo's pager
                      // does; each group carries its own count.
                      if (provider.selectedGroupBy != null) ...[
                        if (provider.groupSummary.isNotEmpty)
                          PaginationControls(
                            canGoToPreviousPage: false,
                            canGoToNextPage: false,
                            onPreviousPage: () {},
                            onNextPage: () {},
                            paginationText: PaginationControls.groupsText(
                              provider.groupSummary.length,
                            ),
                            isDark: isDark,
                            theme: theme,
                          ),
                      ] else if (provider.totalCount > 0 &&
                          provider.items.isNotEmpty)
                        PaginationControls(
                          canGoToPreviousPage: provider.canGoToPreviousPage,
                          canGoToNextPage: provider.canGoToNextPage,
                          onPreviousPage: () => provider.goToPreviousPage(),
                          onNextPage: () => provider.goToNextPage(),
                          paginationText: provider.getPaginationText(),
                          isDark: isDark,
                          theme: theme,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<PickingProvider>(
          builder: (context, provider, child) {
            if (!provider.hasLoadedOnce && provider.items.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.isLoading && provider.items.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.error != null && provider.items.isEmpty) {
              final info = ErrorManager.analyzeError(provider.error!);
              final lottiePath = info.type == ErrorType.moduleNotInstalled
                  ? 'assets/lotties/socialv no data.json'
                  : 'assets/lotties/Error 404.json';

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  children: [
                    const SizedBox(height: 48),
                    EmptyState(
                      title: info.title,
                      subtitle: info.message,
                      lottieAsset: lottiePath,
                      actionLabel: 'Retry',
                      onAction: _onRefresh,
                    ),
                  ],
                ),
              );
            }

            if (provider.items.isEmpty) {
              final hasActiveFilters =
                  _activeFilterCount(provider) > 0 ||
                  provider.selectedGroupBy != null;
              return ListView(
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    title: 'No ${widget.title.toLowerCase()} found',
                    subtitle: hasActiveFilters
                        ? 'Try adjusting your filters'
                        : '${widget.title} will appear here',
                    lottieAsset: 'assets/lotties/empty ghost.json',
                    actionLabel: hasActiveFilters
                        ? 'Clear All Filters'
                        : 'Refresh',
                    onAction: hasActiveFilters ? _clearAllFilters : _onRefresh,
                  ),
                ],
              );
            }

            if (provider.selectedGroupBy != null) {
              if (provider.isLoading && provider.groupSummary.isEmpty) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListShimmer.buildGroupedListShimmer(
                      context,
                      groupCount: 4,
                      itemsPerGroup: 2,
                      type: ShimmerType.standard,
                    ),
                  ),
                );
              }

              for (final groupKey in provider.groupSummary.keys) {
                _expandedGroups.putIfAbsent(groupKey, () => false);
              }

              if (provider.groupSummary.isEmpty) {
                return EmptyState(
                  title: 'No groups found',
                  subtitle: 'Try reloading the groups',
                  lottieAsset: 'assets/lotties/empty ghost.json',
                  actionLabel: 'Reload Groups',
                  onAction: () async {
                    await provider.fetchGroupSummary();
                  },
                );
              }

              // On a short screen the "N groups / Expand All" row is the
              // list's first item, so it scrolls away with the header.
              final compact = isCompactHeight(context);
              final groupKeys = provider.groupSummary.keys.toList();
              final groupList = RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupKeys.length + (compact ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (compact && index == 0) {
                      return _buildGroupsToolbar(
                        provider,
                        isDark,
                        padding: const EdgeInsets.only(bottom: 8),
                      );
                    }
                    return _buildGroupTile(
                      provider,
                      groupKeys[compact ? index - 1 : index],
                      isDark,
                      theme,
                    );
                  },
                ),
              );

              if (compact) return groupList;

              return Column(
                children: [
                  _buildGroupsToolbar(
                    provider,
                    isDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  Expanded(child: groupList),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.items.length,
                itemBuilder: (context, index) {
                  final item = provider.items[index];
                  return PickingListTile(picking: item, isDark: isDark);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// The "N groups" count with the Expand All / Collapse All actions.
  Widget _buildGroupsToolbar(
    PickingProvider provider,
    bool isDark, {
    required EdgeInsetsGeometry padding,
  }) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            provider.groupSummary.length == 1
                ? '1 group'
                : '${provider.groupSummary.length} groups',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              if (!_allGroupsExpanded && provider.groupSummary.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    setState(() {
                      for (final key in provider.groupSummary.keys) {
                        _expandedGroups[key] = true;
                      }
                      _allGroupsExpanded = true;
                    });
                    for (final key in provider.groupSummary.keys) {
                      if (provider.loadedGroups[key] == null ||
                          provider.loadedGroups[key]!.isEmpty) {
                        await provider.loadGroupPickings(key);
                      }
                    }
                  },
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: const Text('Expand All'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              if (_expandedGroups.values.any((expanded) => expanded))
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      for (final key in provider.groupSummary.keys) {
                        _expandedGroups[key] = false;
                      }
                      _allGroupsExpanded = false;
                    });
                  },
                  icon: const Icon(Icons.expand_less, size: 18),
                  label: const Text('Collapse All'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One collapsible group: the §12 grouped section header shell with the
  /// group's pickings below it once expanded.
  Widget _buildGroupTile(
    PickingProvider provider,
    String groupKey,
    bool isDark,
    ThemeData theme,
  ) {
    final count = provider.groupSummary[groupKey]!;
    final isExpanded = _expandedGroups[groupKey] ?? false;
    final loadedItems = provider.loadedGroups[groupKey] ?? [];

    return Container(
      decoration: BoxDecoration(
        // grey[900] in dark so the grey[850] cards nested in the group stay
        // visible.
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: AppShadows.card,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });
              if (!isExpanded && loadedItems.isEmpty) {
                await provider.loadGroupPickings(groupKey);
                if (mounted) setState(() {});
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      groupKey,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  StatusColors.buildStatusBadge(
                    '$count',
                    theme.primaryColor,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: loadedItems
                    .map(
                      (item) => PickingListTile(picking: item, isDark: isDark),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupByPill(PickingProvider provider, ThemeData theme) {
    final label = _groupByLabel(provider.selectedGroupBy);
    return GroupByPill(label: label, theme: theme);
  }

  String _groupByLabel(String? key) {
    switch (key) {
      case 'state':
        return 'Status';
      case 'scheduled_date':
        return 'Date';
      case 'priority':
        return 'Priority';
      default:
        return 'None';
    }
  }

  int _activeFilterCount(PickingProvider provider) {
    int count = 0;
    if (provider.states.isNotEmpty) count++;
    if (provider.startDate != null) count++;
    if (provider.endDate != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  Widget _buildActiveFiltersBadge(PickingProvider provider, ThemeData theme) {
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: _activeFilterCount(provider),
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }
}

/// A specialized screen for managing outgoing stock deliveries.
///
/// Opened from the dashboard's Delivery Orders card, so it starts on the
/// same "To Process" (Ready) filter the card counts.
class DeliveryListScreen extends StatelessWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PickingProvider(
        pickingTypeCode: 'outgoing',
        initialStates: PickingService.toProcessStates,
      )..fetchPickings(),
      child: const PickingListScreen(
        title: 'Delivery Orders',
        pickingTypeCode: 'outgoing',
      ),
    );
  }
}

/// A specialized screen for managing incoming stock receipts.
///
/// Opened from the dashboard's Receipts card, so it starts on the same
/// "To Process" (Ready) filter the card counts.
class ReceiptListScreen extends StatelessWidget {
  const ReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PickingProvider(
        pickingTypeCode: 'incoming',
        initialStates: PickingService.toProcessStates,
      )..fetchPickings(),
      child: const PickingListScreen(
        title: 'Receipts',
        pickingTypeCode: 'incoming',
      ),
    );
  }
}

/// The internal transfers to process, as a plain picking list — what the
/// dashboard's Internal Transfers card opens, on the same "To Process"
/// filter the card counts.
class InternalTransferListScreen extends StatelessWidget {
  const InternalTransferListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PickingProvider(
        pickingTypeCode: 'internal',
        initialStates: PickingService.toProcessStates,
      )..fetchPickings(),
      child: const PickingListScreen(
        title: 'Internal Transfers',
        pickingTypeCode: 'internal',
      ),
    );
  }
}

/// Point of Sale's pickings to process — what the dashboard's PoS Orders card
/// opens. They are outgoing, but kept apart from Delivery Orders as in Odoo.
class PosOrderListScreen extends StatelessWidget {
  const PosOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PickingProvider(
        pickingTypeCode: 'outgoing',
        initialStates: PickingService.toProcessStates,
        service: PickingService(posOrders: true),
        cacheName: 'pos',
      )..fetchPickings(),
      child: const PickingListScreen(
        title: 'PoS Orders',
        pickingTypeCode: 'outgoing',
      ),
    );
  }
}
