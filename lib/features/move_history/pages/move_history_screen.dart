import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../providers/move_history_provider.dart';
import '../widgets/move_history_list_tile.dart';
import '../widgets/move_history_group_tile.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/error_manager.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';

/// A screen displaying a searchable and filterable audit trail of stock movements.
///
/// Provides detailed logs of quantities moved, source/destination locations,
/// and reference numbers for complete stock transparency.
class MoveHistoryScreen extends StatefulWidget {
  const MoveHistoryScreen({super.key});

  @override
  State<MoveHistoryScreen> createState() => _MoveHistoryScreenState();
}

class _MoveHistoryScreenState extends State<MoveHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  /// Groups whose "Load more" is fetching.
  final Set<String> _loadingMoreGroups = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MoveHistoryProvider>();
      _fetchData(provider);
    });
  }

  void _fetchData(MoveHistoryProvider provider) {
    provider.fetchHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final provider = context.read<MoveHistoryProvider>();
        // updateFilters replaces every filter, so the others are passed
        // back as they are: searching narrows the list, it doesn't reset
        // the Done filter or the dates.
        provider.fetchHistory(
          searchQuery: _searchController.text.trim(),
          status: provider.status,
          dateFrom: provider.dateFrom,
          dateTo: provider.dateTo,
          updateFilters: true,
        );
      }
    });
  }

  Future<void> _refreshMoveHistory() async {
    final provider = context.read<MoveHistoryProvider>();
    await provider.refresh();
  }

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilters() {
    final provider = context.read<MoveHistoryProvider>();

    final moveStatusGroup = FilterGroup(
      title: 'Move Status',
      options: [
        FilterOption(title: 'Done', value: provider.status == 'done'),
        FilterOption(title: 'Cancelled', value: provider.status == 'cancel'),
        FilterOption(title: 'Assigned', value: provider.status == 'assigned'),
      ],
    );

    final moveTypeGroup = FilterGroup(
      title: 'Move Type',
      options: [
        FilterOption(
          title: 'Outgoing',
          value: provider.pickingTypeCodes.contains('outgoing'),
        ),
        FilterOption(
          title: 'Internal',
          value: provider.pickingTypeCodes.contains('internal'),
        ),
        FilterOption(
          title: 'Incoming',
          value: provider.pickingTypeCodes.contains('incoming'),
        ),
      ],
    );

    final filterOptionsGroup = FilterGroup(
      title: 'Filter Options',
      options: [
        FilterOption(title: 'Active Only', value: provider.activeOnly),
        FilterOption(title: 'Inventory Only', value: provider.inventoryOnly),
      ],
    );

    final dateRangeGroup = FilterGroup(
      title: 'Date Range',
      options: [
        FilterOption(
          title: 'Start Date',
          value: provider.dateFrom != null,
          selectedValue: provider.dateFrom,
        ),
        FilterOption(
          title: 'End Date',
          value: provider.dateTo != null,
          selectedValue: provider.dateTo,
        ),
      ],
    );

    final isDateGroupBy =
        provider.selectedGroupBy?.startsWith('date:') ?? false;
    const groupBySubtitles = {
      'product': 'Group by product',
      'state': 'Group by move status',
      'location': 'Group by source and destination',
      'category': 'Group by product category',
      'transfer': 'Group by transfer reference',
      'date:day': 'Group by move date',
    };
    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: provider.groupByOptions.entries
          .map(
            (entry) => FilterOption(
              title: entry.value,
              subtitle: groupBySubtitles[entry.key],
              value: entry.key.startsWith('date:')
                  ? isDateGroupBy
                  : provider.selectedGroupBy == entry.key,
              selectedValue: entry.key.startsWith('date:') && isDateGroupBy
                  ? provider.selectedGroupBy!.split(':').last
                  : null,
            ),
          )
          .toList(),
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [
        moveStatusGroup,
        moveTypeGroup,
        filterOptionsGroup,
        dateRangeGroup,
      ],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        String? status;
        if (values['move_status_done'] == true) {
          status = 'done';
        } else if (values['move_status_cancelled'] == true) {
          status = 'cancel';
        } else if (values['move_status_assigned'] == true) {
          status = 'assigned';
        }

        final pickingTypeCodes = <String>[];
        if (values['move_type_outgoing'] == true) {
          pickingTypeCodes.add('outgoing');
        }
        if (values['move_type_internal'] == true) {
          pickingTypeCodes.add('internal');
        }
        if (values['move_type_incoming'] == true) {
          pickingTypeCodes.add('incoming');
        }

        final activeOnly = values['filter_options_active_only'] == true;
        final inventoryOnly = values['filter_options_inventory_only'] == true;

        final dateFrom = values['date_range_start_date'] == true
            ? values['date_range_start_date_value'] as DateTime?
            : null;
        final dateTo = values['date_range_end_date'] == true
            ? values['date_range_end_date_value'] as DateTime?
            : null;

        String? groupBy;
        for (final entry in provider.groupByOptions.entries) {
          final key = 'group_by_${_snake(entry.value)}';
          if (values[key] == true) {
            if (entry.key.startsWith('date:')) {
              final unit = values['${key}_value'] as String? ?? 'day';
              groupBy = 'date:$unit';
            } else {
              groupBy = entry.key;
            }
            break;
          }
        }

        provider.setGroupBy(groupBy);
        provider.fetchHistory(
          status: status,
          pickingTypeCodes: pickingTypeCodes,
          dateFrom: dateFrom,
          dateTo: dateTo,
          activeOnly: activeOnly,
          inventoryOnly: inventoryOnly,
          groupBy: groupBy,
          updateFilters: true,
        );
      },
    );
  }

  bool _hasActiveFilter(MoveHistoryProvider provider) {
    return (provider.status?.isNotEmpty ?? false) ||
        provider.pickingTypeCodes.isNotEmpty ||
        provider.dateFrom != null ||
        provider.dateTo != null ||
        provider.activeOnly ||
        provider.inventoryOnly ||
        provider.selectedGroupBy != null ||
        _searchController.text.trim().isNotEmpty;
  }

  Widget _buildGroupByPill(ThemeData theme, String? groupBy) {
    final label = _groupByLabel(groupBy);
    return GroupByPill(label: label, theme: theme);
  }

  String _groupByLabel(String? key) {
    switch (key) {
      case 'state':
        return 'Status';
      case 'date':
      case 'date:day':
        return 'Date';
      case 'product':
        return 'Product';
      case 'location':
        return 'Location';
      case 'category':
        return 'Category';
      case 'transfer':
        return 'Transfer';
      default:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compact = isCompactHeight(context);

    return Scaffold(
      body: CollapsibleHeaderLayout(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: Consumer<MoveHistoryProvider>(
                builder: (_, provider, __) {
                  return MoboSearchFilterBar(
                    controller: _searchController,
                    hintText: 'Search product or reference...',
                    hasActiveFilter: _hasActiveFilter(provider),
                    onFilterTap: _showFilters,
                    onChanged: (_) => setState(() {}),
                  );
                },
              ),
            ),

            Consumer<MoveHistoryProvider>(
              builder: (_, provider, __) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                _buildGroupByPill(
                                  theme,
                                  provider.selectedGroupBy,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      ..._buildPager(provider, isDark, theme),
                    ],
                  ),
                );
              },
            ),
          ],
        ),

        body: Consumer<MoveHistoryProvider>(
          builder: (_, provider, __) {
            if (!provider.isLoading &&
                !provider.hasLoadedOnce &&
                provider.error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchData(provider);
              });
            }

            if (!provider.hasLoadedOnce && provider.items.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refreshMoveHistory,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListShimmer.buildListShimmer(
                      context,
                      itemCount: 8,
                      type: ShimmerType.standard,
                    ),
                  ),
                ),
              );
            }

            if (provider.isLoading && provider.items.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refreshMoveHistory,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListShimmer.buildListShimmer(
                      context,
                      itemCount: 8,
                      type: ShimmerType.standard,
                    ),
                  ),
                ),
              );
            }

            if (provider.error != null && provider.items.isEmpty) {
              final info = ErrorManager.analyzeError(provider.error!);
              final lottiePath = info.type == ErrorType.moduleNotInstalled
                  ? 'assets/lotties/socialv no data.json'
                  : 'assets/lotties/Error 404.json';

              return EmptyState(
                title: info.title,
                subtitle: info.message,
                lottieAsset: lottiePath,
                actionLabel: 'Retry',
                onAction: () => _refreshMoveHistory(),
              );
            }

            if (provider.items.isEmpty && provider.hasLoadedOnce) {
              final hasActiveFilters = _hasActiveFilter(provider);

              return RefreshIndicator(
                onRefresh: _refreshMoveHistory,
                child: ListView(
                  children: [
                    const SizedBox(height: 48),
                    EmptyState(
                      title: 'No move history found',
                      subtitle: hasActiveFilters
                          ? 'Try adjusting your filters'
                          : 'Stock movements will appear here',
                      lottieAsset: 'assets/lotties/empty ghost.json',
                      actionLabel: hasActiveFilters
                          ? 'Clear All Filters'
                          : 'Refresh',
                      onAction: hasActiveFilters
                          ? _clearAllFilters
                          : _refreshMoveHistory,
                    ),
                  ],
                ),
              );
            }

            final groupBy = provider.selectedGroupBy;

            if (groupBy == null) {
              return RefreshIndicator(
                onRefresh: _refreshMoveHistory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.items.length,
                  itemBuilder: (context, index) {
                    final item = provider.items[index];
                    return MoveHistoryListTile(
                      key: ValueKey(item.id),
                      item: item,
                      isDark: isDark,
                      onTap: () {
                        context.pushNamed(
                          AppRoutes.moveHistoryDetail,
                          extra: item,
                        );
                      },
                    );
                  },
                ),
              );
            }

            // Counted on the server across every matching move line, in
            // Odoo's order — not just the page of lines loaded above.
            final sortedKeys = provider.groupSummary.keys.toList();

            if (sortedKeys.isEmpty) {
              return EmptyState(
                title: 'No groups found',
                subtitle: 'Try reloading the groups',
                lottieAsset: 'assets/lotties/empty ghost.json',
                actionLabel: 'Reload Groups',
                onAction: provider.fetchGroupSummary,
              );
            }

            for (final groupKey in sortedKeys) {
              if (!_expandedGroups.containsKey(groupKey)) {
                _expandedGroups[groupKey] = false;
              }
            }

            // "N groups / Expand All" row: pinned above the list normally,
            // the list's first item on a short screen so it scrolls away
            // with the header.
            final summary = Container(
              padding: compact
                  ? const EdgeInsets.only(bottom: 4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sortedKeys.length} groups',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      if (!_allGroupsExpanded && sortedKeys.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            setState(() {
                              for (final key in sortedKeys) {
                                _expandedGroups[key] = true;
                              }
                              _allGroupsExpanded = true;
                            });
                            for (final key in sortedKeys) {
                              await provider.loadGroupItems(key);
                            }
                          },
                          icon: const Icon(Icons.expand_more, size: 18),
                          label: const Text('Expand All'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      if (_expandedGroups.values.any((expanded) => expanded))
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              for (final key in sortedKeys) {
                                _expandedGroups[key] = false;
                              }
                              _allGroupsExpanded = false;
                            });
                          },
                          icon: const Icon(Icons.expand_less, size: 18),
                          label: const Text('Collapse All'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );

            final groupList = RefreshIndicator(
              onRefresh: _refreshMoveHistory,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, compact ? 8 : 16, 16, 16),
                itemCount: sortedKeys.length + (compact ? 1 : 0),
                itemBuilder: (context, index) {
                  if (compact && index == 0) return summary;
                  final key = sortedKeys[compact ? index - 1 : index];
                  final items = provider.loadedGroups[key];
                  final count = provider.groupSummary[key] ?? 0;
                  final isExpanded = _expandedGroups[key] ?? false;

                  return MoveHistoryGroupTile(
                    groupKey: key,
                    count: count,
                    items: items,
                    isDark: isDark,
                    theme: theme,
                    isExpanded: isExpanded,
                    onToggle: () {
                      setState(() {
                        _expandedGroups[key] = !isExpanded;
                        _allGroupsExpanded = _expandedGroups.values.every(
                          (expanded) => expanded,
                        );
                      });
                      if (!isExpanded) provider.loadGroupItems(key);
                    },
                    footer: items != null && items.length < count
                        ? _buildGroupLoadMore(
                            provider,
                            key,
                            count - items.length,
                          )
                        : null,
                  );
                },
              ),
            );

            if (compact) return groupList;
            return Column(
              children: [
                summary,
                Expanded(child: groupList),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The pager, as Odoo shows it: ungrouped it pages the move lines; a
  /// grouped list pages its groups — each group carries its own count.
  List<Widget> _buildPager(
    MoveHistoryProvider provider,
    bool isDark,
    ThemeData theme,
  ) {
    if (provider.selectedGroupBy != null) {
      if (provider.groupSummary.isEmpty) return const [];
      return [
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
      ];
    }
    if (provider.totalCount == 0 || provider.items.isEmpty) return const [];
    return [
      PaginationControls(
        canGoToPreviousPage: provider.canGoToPreviousPage,
        canGoToNextPage: provider.canGoToNextPage,
        onPreviousPage: provider.goToPreviousPage,
        onNextPage: provider.goToNextPage,
        paginationText: provider.getPaginationText(),
        isDark: isDark,
        theme: theme,
      ),
    ];
  }

  /// "Load more" at the foot of an expanded group showing fewer move lines
  /// than its count.
  Widget _buildGroupLoadMore(
    MoveHistoryProvider provider,
    String groupKey,
    int remaining,
  ) {
    final loading = _loadingMoreGroups.contains(groupKey);
    return TextButton(
      onPressed: loading
          ? null
          : () async {
              setState(() => _loadingMoreGroups.add(groupKey));
              await provider.loadMoreGroupItems(groupKey);
              if (mounted) {
                setState(() => _loadingMoreGroups.remove(groupKey));
              }
            },
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text('Load more ($remaining)'),
    );
  }

  void _clearAllFilters() {
    final provider = context.read<MoveHistoryProvider>();
    _searchController.clear();
    provider.clearFilters();
    provider.fetchHistory();
  }

  Widget _buildActiveFiltersBadge(
    MoveHistoryProvider provider,
    ThemeData theme,
  ) {
    int count = 0;
    if (provider.status?.isNotEmpty ?? false) count++;
    if (provider.pickingTypeCodes.isNotEmpty) count++;
    if (provider.dateFrom != null) count++;
    if (provider.dateTo != null) count++;
    if (provider.activeOnly) count++;
    if (provider.inventoryOnly) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: count,
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }
}
