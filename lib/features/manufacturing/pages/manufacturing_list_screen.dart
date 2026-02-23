import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/manufacturing_provider.dart';
import '../widgets/manufacturing_list_tile.dart';
import '../widgets/manufacturing_filter_bottom_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';

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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
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

  void _clearAllFilters() {
    _searchController.clear();
    final provider = context.read<ManufacturingProvider>();
    provider.clearFilters();
    provider.fetchProductions(forceRefresh: true);
  }

  void _showFilterBottomSheet() {
    final provider = context.read<ManufacturingProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManufacturingFilterBottomSheet(
        provider: provider,
        onClearSearch: () => _searchController.clear(),
      ),
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: TextField(
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search manufacturing orders...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xff1E1E1E),
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                prefixIcon: IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedFilterHorizontal,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 18,
                  ),
                  tooltip: 'Filter & Group By',
                  onPressed: _showFilterBottomSheet,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();

                          context
                              .read<ManufacturingProvider>()
                              .fetchProductions(
                                searchQuery: '',
                                forceRefresh: true,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                isDense: true,
              ),
              onSubmitted: (value) {
                _searchDebouncer.run(() {
                  if (!mounted) return;
                  context.read<ManufacturingProvider>().fetchProductions(
                    searchQuery: value.trim(),
                    forceRefresh: true,
                  );
                  HapticsService.light();
                });
              },
            ),
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
                    if (provider.totalCount > 0 && provider.items.isNotEmpty)
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

          Expanded(
            child: Consumer<ManufacturingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.items.isEmpty) {
                  return ListShimmer.buildListShimmer(
                    context,
                    itemCount: 8,
                    type: ShimmerType.standard,
                  );
                }

                if (provider.error != null && provider.items.isEmpty) {
                  final err = provider.error!.toLowerCase();
                  final isModuleNotInstalled =
                      err.contains('module') && err.contains('not available');
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
                    onRefresh: _onRefresh,
                    child: ListView(
                      children: [
                        const SizedBox(height: 48),
                        EmptyState(
                          title: title,
                          subtitle: subtitle,
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
                      (provider.states.isNotEmpty) ||
                      (provider.startDate != null) ||
                      (provider.endDate != null) ||
                      (provider.selectedGroupBy != null) ||
                      (_searchController.text.trim().isNotEmpty);
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
                        onAction: hasActiveFilters
                            ? _clearAllFilters
                            : _onRefresh,
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
                              '${provider.groupSummary.length} groups',
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
                                if (!_allGroupsExpanded &&
                                    provider.groupSummary.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () async {
                                      setState(() {
                                        for (final key
                                            in provider.groupSummary.keys) {
                                          _expandedGroups[key] = true;
                                        }
                                        _allGroupsExpanded = true;
                                      });
                                      for (final key
                                          in provider.groupSummary.keys) {
                                        if (provider.loadedGroups[key] ==
                                                null ||
                                            provider
                                                .loadedGroups[key]!
                                                .isEmpty) {
                                          await provider.loadGroupProductions(
                                            key,
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.expand_more,
                                      size: 18,
                                    ),
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
                                        for (final key
                                            in provider.groupSummary.keys) {
                                          _expandedGroups[key] = false;
                                        }
                                        _allGroupsExpanded = false;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.expand_less,
                                      size: 18,
                                    ),
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
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.groupSummary.length,
                            itemBuilder: (context, index) {
                              final groupKey = provider.groupSummary.keys
                                  .elementAt(index);
                              final count = provider.groupSummary[groupKey]!;
                              final isExpanded =
                                  _expandedGroups[groupKey] ?? false;
                              final loadedItems =
                                  provider.loadedGroups[groupKey] ?? [];

                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.06),
                                  ),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                        color: Colors.black.withOpacity(0.08),
                                      ),
                                  ],
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _expandedGroups[groupKey] =
                                              !isExpanded;
                                        });
                                        if (!isExpanded &&
                                            loadedItems.isEmpty) {
                                          await provider.loadGroupProductions(
                                            groupKey,
                                          );
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
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme.primaryColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: theme.iconTheme.color,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                          right: 16,
                                          bottom: 16,
                                        ),
                                        child: Column(
                                          children: loadedItems
                                              .map(
                                                (item) => ManufacturingListTile(
                                                  item: item,
                                                  isDark: isDark,
                                                  onTap: () {},
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
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
                        onTap: () {},
                      );
                    },
                  ),
                );
              },
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
