import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/manufacturing_provider.dart';
import '../widgets/manufacturing_list_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/error_manager.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';

/// A screen for managing and tracking manufacturing orders (MOs).
///
/// Provides a comprehensive list view with real-time status tracking,
/// date filtering, and grouping by state for production oversight.
class ManufacturingListScreen extends StatefulWidget {
  const ManufacturingListScreen({super.key});

  @override
  State<ManufacturingListScreen> createState() =>
      _ManufacturingListScreenState();
}

class _ManufacturingListScreenState extends State<ManufacturingListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);
  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ManufacturingProvider>();
      provider.fetchProductions();
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
      context.read<ManufacturingProvider>().fetchProductions(
        searchQuery: _searchController.text.trim(),
        forceRefresh: true,
      );
      HapticsService.light();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<ManufacturingProvider>().fetchProductions(
      forceRefresh: true,
    );
  }

  bool _hasActiveFilter(ManufacturingProvider provider) {
    return provider.states.isNotEmpty ||
        provider.startDate != null ||
        provider.endDate != null ||
        provider.selectedGroupBy != null ||
        _searchController.text.trim().isNotEmpty;
  }

  void _clearAllFilters() {
    _searchController.clear();
    final provider = context.read<ManufacturingProvider>();
    provider.clearFilters();
    provider.fetchProductions(forceRefresh: true);
  }

  static const List<String> _allStates = [
    'draft',
    'confirmed',
    'planned',
    'progress',
    'to_close',
    'done',
    'cancel',
  ];

  static String _stateLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Draft';
      case 'confirmed':
        return 'Confirmed';
      case 'planned':
        return 'Planned';
      case 'progress':
        return 'In Progress';
      case 'to_close':
        return 'To Close';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return s;
    }
  }

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilterBottomSheet() {
    final provider = context.read<ManufacturingProvider>();

    final statusGroup = FilterGroup(
      title: 'Status',
      options: _allStates
          .map(
            (s) => FilterOption(
              title: _stateLabel(s),
              value: provider.states.contains(s),
            ),
          )
          .toList(),
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
          subtitle: 'Group by manufacturing status',
          value: provider.selectedGroupBy == 'state',
        ),
        FilterOption(
          title: 'Date',
          subtitle: 'Group by created date',
          value: provider.selectedGroupBy == 'create_date',
        ),
      ],
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [statusGroup, dateRangeGroup],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        final selectedStates = _allStates
            .where((s) => values['status_${_snake(_stateLabel(s))}'] == true)
            .toList();

        final startDate = values['date_range_start_date'] == true
            ? values['date_range_start_date_value'] as DateTime?
            : null;
        final endDate = values['date_range_end_date'] == true
            ? values['date_range_end_date_value'] as DateTime?
            : null;

        String? groupBy;
        if (values['group_by_status'] == true) {
          groupBy = 'state';
        } else if (values['group_by_date'] == true) {
          groupBy = 'create_date';
        }

        provider.setGroupBy(groupBy);
        provider.fetchProductions(
          states: selectedStates,
          startDate: startDate,
          endDate: endDate,
          forceRefresh: true,
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
          'Manufacturing Orders',
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
            Consumer<ManufacturingProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.scaffoldBackgroundColor,
                  child: MoboSearchFilterBar(
                    controller: _searchController,
                    hintText: 'Search manufacturing orders...',
                    hasActiveFilter: _hasActiveFilter(provider),
                    onFilterTap: _showFilterBottomSheet,
                    onChanged: (_) => setState(() {}),
                  ),
                );
              },
            ),

            Consumer<ManufacturingProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
        body: Consumer<ManufacturingProvider>(
          builder: (context, provider, child) {
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
                      onAction: () => _onRefresh(),
                    ),
                  ],
                ),
              );
            }

            if (provider.items.isEmpty) {
              final hasActiveFilters = _hasActiveFilter(provider);
              return ListView(
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    title: 'No manufacturing orders found',
                    subtitle: hasActiveFilters
                        ? 'Try adjusting your filters'
                        : 'Manufacturing orders will appear here',
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
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                itemCount: provider.items.length,
                itemBuilder: (context, index) {
                  final item = provider.items[index];
                  return ManufacturingListTile(
                    item: item,
                    isDark: isDark,
                  );
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
    ManufacturingProvider provider,
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
                        await provider.loadGroupProductions(key);
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
  /// group's orders below it once expanded.
  Widget _buildGroupTile(
    ManufacturingProvider provider,
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
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () async {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });
              if (!isExpanded && loadedItems.isEmpty) {
                await provider.loadGroupProductions(groupKey);
                if (mounted) setState(() {});
              }
            },
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
                    isExpanded ? Icons.expand_less : Icons.expand_more,
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
                      (item) => ManufacturingListTile(
                        item: item,
                        isDark: isDark,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupByPill(ManufacturingProvider provider, ThemeData theme) {
    final label = _groupByLabel(provider.selectedGroupBy);
    return GroupByPill(label: label, theme: theme);
  }

  String _groupByLabel(String? key) {
    switch (key) {
      case 'state':
        return 'Status';
      case 'create_date':
        return 'Date';
      default:
        return 'None';
    }
  }

  Widget _buildActiveFiltersBadge(
    ManufacturingProvider provider,
    ThemeData theme,
  ) {
    int count = 0;
    if (provider.states.isNotEmpty) count++;
    if (provider.startDate != null) count++;
    if (provider.endDate != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: count,
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }
}
