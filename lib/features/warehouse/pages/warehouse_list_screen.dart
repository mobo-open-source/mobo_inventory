import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/warehouse_list_tile.dart';
import '../models/warehouse_model.dart';
import '../widgets/warehouse_group_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/error_manager.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';

/// A screen displaying a searchable and filterable list of all warehouses.
///
/// Supports grouping by company, short code, and alphabetical categorization
/// to help manage complex multi-warehouse organizational structures.
class WarehouseListScreen extends StatefulWidget {
  final bool asTab;
  const WarehouseListScreen({super.key, this.asTab = false});

  @override
  State<WarehouseListScreen> createState() => _WarehouseListScreenState();
}

class _WarehouseListScreenState extends State<WarehouseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WarehouseProvider>();
      provider.fetchWarehouses();
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
        final provider = context.read<WarehouseProvider>();
        provider.fetchWarehouses(searchQuery: _searchController.text.trim());
      }
    });
  }

  Future<void> _refreshWarehouses() async {
    final provider = context.read<WarehouseProvider>();
    await provider.refresh();
  }

  void _clearAllFilters() {
    _searchController.clear();
    final provider = context.read<WarehouseProvider>();
    provider.clearFilters();
    provider.fetchWarehouses(forceRefresh: true);
  }

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilterBottomSheet() {
    final provider = context.read<WarehouseProvider>();

    final filterOptionsGroup = FilterGroup(
      title: 'Filter Options',
      options: [
        FilterOption(
          title: 'Has Stock Location',
          value: provider.filterHasStockLocation,
        ),
        FilterOption(title: 'Has Code', value: provider.filterHasCode),
      ],
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: [
        FilterOption(
          title: 'Company',
          subtitle: 'Group by company',
          value: provider.selectedGroupBy == 'company',
        ),
        FilterOption(
          title: 'Code',
          subtitle: 'Group by short code',
          value: provider.selectedGroupBy == 'code',
        ),
        FilterOption(
          title: 'Name (A-Z)',
          subtitle: 'Group by first letter of name',
          value: provider.selectedGroupBy == 'name:letter',
        ),
      ],
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [filterOptionsGroup],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        final hasStockLocation =
            values['filter_options_${_snake('Has Stock Location')}'] == true;
        final hasCode = values['filter_options_${_snake('Has Code')}'] == true;

        String? groupBy;
        if (values['group_by_${_snake('Company')}'] == true) {
          groupBy = 'company';
        } else if (values['group_by_${_snake('Code')}'] == true) {
          groupBy = 'code';
        } else if (values['group_by_${_snake('Name (A-Z)')}'] == true) {
          groupBy = 'name:letter';
        }

        provider.setGroupBy(groupBy);
        provider.setFilterHasStockLocation(hasStockLocation);
        provider.setFilterHasCode(hasCode);
        provider.fetchWarehouses(forceRefresh: true);
      },
    );
  }

  Widget _buildGroupByPill(ThemeData theme, String? groupBy) {
    if (groupBy == null) return const SizedBox.shrink();
    String label;
    switch (groupBy) {
      case 'company':
        label = 'Company';
        break;
      case 'code':
        label = 'Code';
        break;
      case 'name:letter':
        label = 'Name (A-Z)';
        break;
      default:
        label = 'Custom';
    }
    return GroupByPill(label: label, theme: theme);
  }

  Widget _buildActiveFiltersBadge(
    WarehouseProvider provider,
    ThemeData theme,
    TextEditingController controller,
  ) {
    int count = 0;
    if (provider.filterHasStockLocation) count++;
    if (provider.filterHasCode) count++;
    if (controller.text.trim().isNotEmpty) count++;
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: count,
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }

  bool _hasActiveFilter(WarehouseProvider provider) {
    return provider.filterHasStockLocation ||
        provider.filterHasCode ||
        _searchController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<WarehouseProvider>();

    return Scaffold(
      appBar: widget.asTab
          ? null
          : AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  HugeIcons.strokeRoundedArrowLeft01,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              title: Text(
                'Warehouses',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

      body: CollapsibleHeaderLayout(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: MoboSearchFilterBar(
                controller: _searchController,
                hintText: 'Search warehouses...',
                hasActiveFilter: _hasActiveFilter(provider),
                onFilterTap: _showFilterBottomSheet,
                onChanged: (_) => setState(() {}),
              ),
            ),

            Consumer<WarehouseProvider>(
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
                              _buildActiveFiltersBadge(
                                provider,
                                theme,
                                _searchController,
                              ),
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
                      if (provider.totalCount > 0 &&
                          provider.warehouses.isNotEmpty)
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
          ],
        ),

        body: Consumer<WarehouseProvider>(
          builder: (_, provider, __) {
            if (provider.isLoading && provider.warehouses.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.error != null && provider.warehouses.isEmpty) {
              final info = ErrorManager.analyzeError(provider.error!);
              final lottiePath = info.type == ErrorType.moduleNotInstalled
                  ? 'assets/lotties/socialv no data.json'
                  : 'assets/lotties/Error 404.json';

              return ListView(
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    title: info.title,
                    subtitle: info.message,
                    lottieAsset: lottiePath,
                    actionLabel: 'Retry',
                    onAction: _refreshWarehouses,
                  ),
                ],
              );
            }

            if (provider.warehouses.isEmpty) {
              final hasActiveFilters =
                  _hasActiveFilter(provider) ||
                  provider.selectedGroupBy != null;

              return ListView(
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    title: 'No warehouses found',
                    subtitle: hasActiveFilters
                        ? 'Try adjusting your filters'
                        : 'Warehouses will appear here',
                    lottieAsset: 'assets/lotties/empty ghost.json',
                    actionLabel: hasActiveFilters
                        ? 'Clear All Filters'
                        : 'Refresh',
                    onAction: hasActiveFilters
                        ? _clearAllFilters
                        : _refreshWarehouses,
                  ),
                ],
              );
            }

            final groupBy = provider.selectedGroupBy;

            if (groupBy == null) {
              return RefreshIndicator(
                onRefresh: _refreshWarehouses,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.warehouses.length,
                  itemBuilder: (context, index) {
                    final warehouse = provider.warehouses[index];
                    return WarehouseListTile(
                      key: ValueKey(warehouse.id),
                      warehouse: warehouse,
                      isDark: isDark,
                    );
                  },
                ),
              );
            }

            final groups = _buildGroups(provider, groupBy);
            final keys = groups.keys.toList()..sort();

            return RefreshIndicator(
              onRefresh: _refreshWarehouses,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final key = keys[index];
                  final items = groups[key]!;
                  return WarehouseGroupTile(
                    groupKey: key,
                    count: items.length,
                    items: items,
                    isDark: isDark,
                    theme: theme,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, List<Warehouse>> _buildGroups(
    WarehouseProvider provider,
    String groupBy,
  ) {
    final map = <String, List<Warehouse>>{};
    for (final w in provider.warehouses) {
      String key;
      switch (groupBy) {
        case 'company':
          key = (w.companyName?.trim().isNotEmpty ?? false)
              ? (w.companyName!)
              : 'Unknown';
          break;
        case 'code':
          key = (w.code?.trim().isNotEmpty ?? false) ? (w.code!) : '-';
          break;
        case 'name:letter':
          final first = (w.name.trim().isNotEmpty
              ? w.name.trim()[0].toUpperCase()
              : '#');
          key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
          break;
        default:
          key = 'Other';
      }
      map.putIfAbsent(key, () => []).add(w);
    }
    return map;
  }
}
