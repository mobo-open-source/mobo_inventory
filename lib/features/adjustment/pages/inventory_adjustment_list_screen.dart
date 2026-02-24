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
import '../widgets/filterbottomsheetWidget.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';

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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          FilterBottomSheet(provider: context.read<AdjustmentProvider>()),
    );
  }

  Widget _buildGroupByPill(ThemeData theme, String? key) {
    final label = _groupByLabel(key);
    return GroupByPill(label: label, theme: theme);
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: TextField(
              onTapOutside: (val) {
                FocusScope.of(context).unfocus();
              },
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
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
            ),
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

          Expanded(
            child: Consumer<AdjustmentProvider>(
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
                  final hasActiveFilters =
                      provider.onHandFlag ||
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
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasActiveFilters
                              ? 'Try adjusting your filters'
                              : 'No inventory adjustments found',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
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
                    final hasActiveFilters =
                        provider.onHandFlag ||
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
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          if (hasActiveFilters) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _clearAllFilters,
                              icon: const Icon(Icons.clear_all, size: 20),
                              label: const Text('Clear All Filters'),
                              style: ElevatedButton.styleFrom(
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
                          ],
                        ],
                      ),
                    );
                  }

                  final sortedKeys = groupedAdjustments.keys.toList()..sort();

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
                                if (!_allGroupsExpanded &&
                                    sortedKeys.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () async {
                                      setState(() {
                                        for (final key in sortedKeys) {
                                          _expandedGroups[key] = true;
                                        }
                                        _allGroupsExpanded = true;
                                      });
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
                                        for (final key in sortedKeys) {
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
                          onRefresh: _refreshAdjustments,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: sortedKeys.length,
                            itemBuilder: (context, index) {
                              final groupKey = sortedKeys[index];
                              final items = groupedAdjustments[groupKey]!;
                              final isExpanded =
                                  _expandedGroups[groupKey] ?? false;

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
                                      onTap: () {
                                        setState(() {
                                          _expandedGroups[groupKey] =
                                              !isExpanded;
                                          _allGroupsExpanded = _expandedGroups
                                              .values
                                              .every((expanded) => expanded);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                _getGroupIcon(
                                                  provider.selectedGroupBy,
                                                ),
                                                color: theme.primaryColor,
                                                size: 20,
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
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${items.length} ${items.length == 1 ? 'adjustment' : 'adjustments'}',
                                                    style: TextStyle(
                                                      fontSize: 13,
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
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
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
                                                  key: ValueKey(
                                                    'adjustment_${adj.id}',
                                                  ),
                                                  adjustment: adj,
                                                  isDark: isDark,
                                                  onTap: () =>
                                                      _showAdjustmentDialog(
                                                        adj,
                                                      ),
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
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshAdjustments,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
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
        ],
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
