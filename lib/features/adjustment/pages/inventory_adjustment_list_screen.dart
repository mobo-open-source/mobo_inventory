import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/errors/universal_error_widget.dart';
import '../providers/adjustment_provider.dart';
import '../widgets/adjustmentListTileWidget.dart';
import '../widgets/adjustmentDialogWidget.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../../../core/theme/app_theme.dart';

/// Screen displaying a searchable and filterable list of stock quants for inventory adjustment.
class InventoryAdjustmentListScreen extends StatefulWidget {
  const InventoryAdjustmentListScreen({super.key});

  @override
  State<InventoryAdjustmentListScreen> createState() =>
      _InventoryAdjustmentListScreenState();
}

class _InventoryAdjustmentListScreenState
    extends State<InventoryAdjustmentListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdjustmentProvider>();
      provider.fetchAdjustments();
    });
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
        final provider = context.read<AdjustmentProvider>();
        provider.fetchAdjustments(
          searchQuery: _searchController.text.trim(),
          locationId: null,
          updateFilters: true,
        );
      }
    });
  }

  Future<void> _refreshAdjustments() async {
    final provider = context.read<AdjustmentProvider>();
    await provider.refresh();
  }

  static String _filterKey(String s) => s.toLowerCase().replaceAll(' ', '_');

  static const Map<String, String> _groupByFields = {
    'Location': 'location_id',
    'Product': 'product_id',
    'Category': 'product_categ_id',
    'Company': 'company_id',
    'Lot/Serial': 'lot_id',
  };

  static const Map<String, String> _groupBySubtitles = {
    'Location': 'Group by stock location',
    'Product': 'Group by product',
    'Category': 'Group by product category',
    'Company': 'Group by company',
    'Lot/Serial': 'Group by lot or serial number',
  };

  void _showFilterBottomSheet() {
    final provider = context.read<AdjustmentProvider>();

    final locationTypeGroup = FilterGroup(
      title: 'Location Type',
      options: [
        FilterOption(
          title: 'Internal',
          value: provider.filterInternalLocations,
        ),
        FilterOption(title: 'Transit', value: provider.filterTransitLocations),
      ],
    );

    final stockStatusGroup = FilterGroup(
      title: 'Stock Status',
      options: [
        FilterOption(title: 'On Hand', value: provider.onHandFlag),
        FilterOption(title: 'In Stock', value: provider.filterInStock),
        FilterOption(
          title: 'Negative Stock',
          value: provider.filterNegativeStock,
        ),
        FilterOption(
          title: 'Quantity Positive',
          value: provider.quantityPositive,
        ),
      ],
    );

    final countStatusGroup = FilterGroup(
      title: 'Count Status',
      options: [
        FilterOption(title: 'To Count', value: provider.filterToCount),
        FilterOption(title: 'Counted Set', value: provider.countedSet),
        FilterOption(title: 'To Apply', value: provider.filterToApply),
      ],
    );

    final otherGroup = FilterGroup(
      title: 'Other',
      options: [
        FilterOption(title: 'Conflicts', value: provider.filterConflicts),
        FilterOption(title: 'Reserved Only', value: provider.reservedOnly),
        FilterOption(title: 'Mine Only', value: provider.mineOnly),
        FilterOption(
          title: 'Incoming To Today',
          value: provider.incomingDateToToday,
        ),
      ],
    );

    final incomingDateGroup = FilterGroup(
      title: 'Incoming Date',
      options: [
        FilterOption(
          title: 'Start Date',
          value: provider.incomingDateStart != null,
          selectedValue: provider.incomingDateStart,
        ),
        FilterOption(
          title: 'End Date',
          value: provider.incomingDateEnd != null,
          selectedValue: provider.incomingDateEnd,
        ),
      ],
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: _groupByFields.entries
          .map(
            (entry) => FilterOption(
              title: entry.key,
              subtitle: _groupBySubtitles[entry.key],
              value: provider.selectedGroupBy == entry.value,
            ),
          )
          .toList(),
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [
        locationTypeGroup,
        stockStatusGroup,
        countStatusGroup,
        otherGroup,
        incomingDateGroup,
      ],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        bool flag(String key) => values[key] == true;

        final tempInternal = flag('location_type_internal');
        final tempTransit = flag('location_type_transit');
        // Replicates the old FilterBottomSheet's exact fallback logic:
        // if neither location type is selected, default to showing both.
        final finalInternal = tempInternal || (!tempInternal && !tempTransit);
        final finalTransit = tempTransit || (!tempInternal && !tempTransit);

        final onHandFlag = flag('stock_status_on_hand');
        final inStock = flag('stock_status_in_stock');
        final negativeStock = flag('stock_status_negative_stock');
        final quantityPositive = flag('stock_status_quantity_positive');

        final toCount = flag('count_status_to_count');
        final countedSet = flag('count_status_counted_set');
        final toApply = flag('count_status_to_apply');

        final conflicts = flag('other_conflicts');
        final reservedOnly = flag('other_reserved_only');
        final mineOnly = flag('other_mine_only');
        final incomingDateToToday = flag('other_incoming_to_today');

        final incomingDateStart =
            values['incoming_date_start_date_value'] as DateTime?;
        final incomingDateEnd =
            values['incoming_date_end_date_value'] as DateTime?;

        String? groupBy;
        for (final entry in _groupByFields.entries) {
          if (flag('group_by_${_filterKey(entry.key)}')) {
            groupBy = entry.value;
            break;
          }
        }

        provider.setGroupBy(groupBy);
        provider.fetchAdjustments(
          searchQuery: provider.searchQuery,
          locationId: null,
          internalLocations: finalInternal,
          transitLocations: finalTransit,
          onHand: provider.filterOnHand,
          onHandFlag: onHandFlag,
          quantityPositive: quantityPositive,
          toCount: toCount,
          countedSet: countedSet,
          toApply: toApply,
          inStock: inStock,
          conflicts: conflicts,
          negativeStock: negativeStock,
          reservedOnly: reservedOnly,
          mineOnly: mineOnly,
          incomingDateStart: incomingDateStart,
          incomingDateEnd: incomingDateEnd,
          incomingDateToToday: incomingDateToToday,
          updateFilters: true,
        );
      },
    );
  }

  Widget _buildGroupByPill(ThemeData theme, String? key) {
    final label = _groupByLabel(key);
    return GroupByPill(label: label, theme: theme);
  }

  bool _hasActiveFilter(AdjustmentProvider provider) {
    return provider.onHandFlag ||
        provider.quantityPositive ||
        provider.filterNegativeStock ||
        provider.incomingDateToToday ||
        provider.filterConflicts ||
        provider.countedSet ||
        provider.filterToApply ||
        provider.filterToCount ||
        provider.filterInStock ||
        provider.reservedOnly ||
        provider.mineOnly ||
        provider.incomingDateStart != null ||
        provider.incomingDateEnd != null ||
        provider.selectedGroupBy != null ||
        _searchController.text.trim().isNotEmpty;
  }

  String _groupByLabel(String? key) {
    switch (key) {
      case 'location_id':
        return 'Location';
      case 'product_id':
        return 'Product';
      case 'product_categ_id':
        return 'Category';
      case 'company_id':
        return 'Company';
      case 'lot_id':
        return 'Lot/Serial';
      default:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final compact = isCompactHeight(context);

    return Scaffold(
      body: CollapsibleHeaderLayout(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer<AdjustmentProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.scaffoldBackgroundColor,
                  child: MoboSearchFilterBar(
                    controller: _searchController,
                    hintText: 'Search products...',
                    hasActiveFilter: _hasActiveFilter(provider),
                    onFilterTap: _showFilterBottomSheet,
                    onChanged: (_) => setState(() {}),
                  ),
                );
              },
            ),

            Consumer<AdjustmentProvider>(
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

        body: Consumer<AdjustmentProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.adjustments.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.error != null && provider.adjustments.isEmpty) {
              return UniversalErrorWidget(
                error: provider.error!,
                onRetry: () async {
                  await provider.refresh();
                },
              );
            }

            if (provider.adjustments.isEmpty) {
              final hasActiveFilters = _hasActiveFilter(provider);

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedEdit02,
                      size: 64,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Adjustments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasActiveFilters
                          ? 'Try adjusting your filters'
                          : 'No inventory adjustments found',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: hasActiveFilters
                            ? _clearAllFilters
                            : _refreshAdjustments,
                        icon: Icon(
                          hasActiveFilters ? Icons.clear_all : Icons.refresh,
                          size: 20,
                        ),
                        label: Text(
                          hasActiveFilters ? 'Clear All Filters' : 'Refresh',
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (provider.selectedGroupBy != null) {
              final groupedAdjustments = <String, List<dynamic>>{};

              for (final adjustment in provider.adjustments) {
                String groupKey;
                switch (provider.selectedGroupBy) {
                  case 'location_id':
                    groupKey = adjustment.location ?? 'Unknown Location';
                    break;
                  case 'product_id':
                    groupKey = adjustment.productName ?? 'Unknown Product';
                    break;
                  case 'product_categ_id':
                    groupKey = 'Unknown Category';
                    break;
                  case 'company_id':
                    groupKey = 'Unknown Company';
                    break;
                  case 'lot_id':
                    groupKey = adjustment.lotSerial ?? 'No Lot/Serial';
                    break;
                  default:
                    groupKey = 'Other';
                }
                groupedAdjustments
                    .putIfAbsent(groupKey, () => [])
                    .add(adjustment);
              }

              for (final key in groupedAdjustments.keys) {
                _expandedGroups.putIfAbsent(key, () => false);
              }

              if (groupedAdjustments.isEmpty) {
                final hasActiveFilters = _hasActiveFilter(provider);

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedLayersLogo,
                        size: 56,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No groups found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _clearAllFilters,
                            icon: const Icon(Icons.clear_all, size: 20),
                            label: const Text('Clear All Filters'),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final sortedKeys = groupedAdjustments.keys.toList()..sort();

              // "N groups / Expand All" row: pinned above the list
              // normally, the list's first item on a short screen so it
              // scrolls away with the header.
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
                onRefresh: _refreshAdjustments,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, compact ? 8 : 16, 16, 16),
                  itemCount: sortedKeys.length + (compact ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (compact && index == 0) return summary;
                    final groupKey = sortedKeys[compact ? index - 1 : index];
                    final items = groupedAdjustments[groupKey]!;
                    final isExpanded = _expandedGroups[groupKey] ?? false;

                    return Container(
                      decoration: BoxDecoration(
                        // grey[900] in dark so the grey[850] cards
                        // nested in the group stay visible.
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
                            onTap: () {
                              setState(() {
                                _expandedGroups[groupKey] = !isExpanded;
                                _allGroupsExpanded = _expandedGroups.values
                                    .every((expanded) => expanded);
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getGroupIcon(provider.selectedGroupBy),
                                      color: theme.primaryColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          groupKey,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${items.length} ${items.length == 1 ? 'adjustment' : 'adjustments'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpanded) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 16,
                              ),
                              child: Column(
                                children: items
                                    .map(
                                      (adj) => AdjustmentListTile(
                                        key: ValueKey('adjustment_${adj.id}'),
                                        adjustment: adj,
                                        isDark: isDark,
                                        onTap: () => _showAdjustmentDialog(adj),
                                        isInGroup: true,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
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
            }

            return RefreshIndicator(
              onRefresh: _refreshAdjustments,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: provider.adjustments.length,
                itemBuilder: (context, index) {
                  final adjustment = provider.adjustments[index];
                  return AdjustmentListTile(
                    key: ValueKey('adjustment_${adjustment.id}_$index'),
                    adjustment: adjustment,
                    isDark: isDark,
                    onTap: () => _showAdjustmentDialog(adjustment),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAdjustmentDialog(dynamic adjustment) {
    showDialog(
      context: context,
      builder: (context) => AdjustmentDialog(adjustment: adjustment),
    );
  }

  void _clearAllFilters() {
    final provider = context.read<AdjustmentProvider>();
    _searchController.clear();
    provider.clearFilters();
    provider.fetchAdjustments();
  }

  IconData _getGroupIcon(String? groupByField) {
    switch (groupByField) {
      case 'location_id':
        return Icons.location_on_outlined;
      case 'product_id':
        return Icons.inventory_2_outlined;
      case 'product_categ_id':
        return Icons.category_outlined;
      case 'company_id':
        return Icons.business_outlined;
      case 'lot_id':
        return Icons.qr_code_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Widget _buildActiveFiltersBadge(
    AdjustmentProvider provider,
    ThemeData theme,
  ) {
    int count = 0;
    if (provider.onHandFlag) count++;
    if (provider.quantityPositive) count++;
    if (provider.filterNegativeStock) count++;
    if (provider.incomingDateToToday) count++;
    if (provider.filterConflicts) count++;
    if (provider.countedSet) count++;
    if (provider.filterToApply) count++;
    if (provider.filterToCount) count++;
    if (provider.filterInStock) count++;
    if (provider.reservedOnly) count++;
    if (provider.mineOnly) count++;
    if (provider.incomingDateStart != null) count++;
    if (provider.incomingDateEnd != null) count++;
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: count,
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }
}
