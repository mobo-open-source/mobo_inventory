import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/move_history_provider.dart';
import '../widgets/move_history_list_tile.dart';
import '../widgets/move_history_group_tile.dart';
import '../widgets/move_history_filter_bottom_sheet.dart';
import '../models/move_history_item.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';

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
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final provider = context.read<MoveHistoryProvider>();
        provider.fetchHistory(
          searchQuery: _searchController.text.trim(),
          updateFilters: true,
        );
      }
    });
  }

  Future<void> _refreshMoveHistory() async {
    final provider = context.read<MoveHistoryProvider>();
    await provider.refresh();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoveHistoryFilterBottomSheet(
        provider: context.read<MoveHistoryProvider>(),
        onClearSearch: () => _searchController.clear(),
      ),
    );
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              onSubmitted: (val) {
                context.read<MoveHistoryProvider>().fetchHistory(
                  searchQuery: val.trim(),
                  updateFilters: true,
                );
              },
              decoration: InputDecoration(
                hintText: 'Search product or reference...',
                prefixIcon: IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedFilterHorizontal,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 18,
                  ),
                  onPressed: () => _showFilters(),
                  tooltip: 'Filter & Group By',
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          context.read<MoveHistoryProvider>().fetchHistory(
                            searchQuery: '',
                            updateFilters: true,
                          );
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                isDense: true,
              ),
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
                    if (provider.totalCount > 0 && provider.items.isNotEmpty)
                      PaginationControls(
                        canGoToPreviousPage: provider.canGoToPreviousPage,
                        canGoToNextPage: provider.canGoToNextPage,
                        onPreviousPage: provider.goToPreviousPage,
                        onNextPage: provider.goToNextPage,
                        paginationText: provider.getPaginationText(),
                        isDark: isDark,
                        theme: theme,
                      ),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: Consumer<MoveHistoryProvider>(
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

                  return RefreshIndicator(
                    onRefresh: () => _refreshMoveHistory(),
                    child: ListView(
                      children: [
                        const SizedBox(height: 48),
                        EmptyState(
                          title: title,
                          subtitle: subtitle,
                          lottieAsset: lottiePath,
                          actionLabel: 'Retry',
                          onAction: () => _refreshMoveHistory(),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.items.isEmpty && provider.hasLoadedOnce) {
                  final hasActiveFilters =
                      (provider.status?.isNotEmpty ?? false) ||
                      provider.pickingTypeCodes.isNotEmpty ||
                      provider.dateFrom != null ||
                      provider.dateTo != null ||
                      provider.activeOnly ||
                      provider.inventoryOnly ||
                      provider.selectedGroupBy != null ||
                      _searchController.text.trim().isNotEmpty;

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
                      controller: _scrollController,
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

                final groups = _buildGroups(provider.items, groupBy);
                final sortedKeys = groups.keys.toList()..sort();

                for (final groupKey in sortedKeys) {
                  if (!_expandedGroups.containsKey(groupKey)) {
                    _expandedGroups[groupKey] = false;
                  }
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${sortedKeys.length} groups',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              if (!_allGroupsExpanded && sortedKeys.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      for (final key in sortedKeys) {
                                        _expandedGroups[key] = true;
                                      }
                                      _allGroupsExpanded = true;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_more, size: 18),
                                  label: const Text('Expand All'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              if (_expandedGroups.values.any(
                                (expanded) => expanded,
                              ))
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
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshMoveHistory,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedKeys.length,
                          itemBuilder: (context, index) {
                            final key = sortedKeys[index];
                            final items = groups[key]!;
                            final isExpanded = _expandedGroups[key] ?? false;

                            return MoveHistoryGroupTile(
                              groupKey: key,
                              count: items.length,
                              items: items,
                              isDark: isDark,
                              theme: theme,
                              isExpanded: isExpanded,
                              onToggle: () {
                                setState(() {
                                  _expandedGroups[key] = !isExpanded;
                                  _allGroupsExpanded = _expandedGroups.values
                                      .every((expanded) => expanded);
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<MoveHistoryItem>> _buildGroups(
    List<MoveHistoryItem> items,
    String? groupBy,
  ) {
    final groups = <String, List<MoveHistoryItem>>{};

    for (final item in items) {
      final key = _getGroupKey(item, groupBy);
      groups.putIfAbsent(key, () => []).add(item);
    }

    return groups;
  }

  String _getGroupKey(MoveHistoryItem item, String? groupBy) {
    switch (groupBy) {
      case 'product':
        return item.product ?? 'Unknown';
      case 'state':
        return _getStatusLabel(item.status);
      case 'location':
        final from = item.fromLocation ?? '-';
        final to = item.toLocation ?? '-';
        return '$from → $to';
      case 'category':
        return item.productCategory ?? 'Unknown';
      case 'transfer':
        return item.transfer ?? 'Unknown';
      case 'date:day':
        final dt = item.date?.toLocal();
        if (dt == null) return 'Unknown';
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      default:
        return 'Other';
    }
  }

  String _getStatusLabel(String? state) {
    switch (state) {
      case 'draft':
        return 'New';
      case 'waiting':
        return 'Waiting Another Move';
      case 'confirmed':
        return 'Waiting Availability';
      case 'partially_available':
        return 'Partially Available';
      case 'assigned':
        return 'Available';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return state?.toUpperCase() ?? 'Unknown';
    }
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
