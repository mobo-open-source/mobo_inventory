import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/warehouse_list_tile.dart';
import '../models/warehouse_model.dart';
import '../widgets/warehouse_filter_bottom_sheet.dart';
import '../widgets/warehouse_group_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';

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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
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

  void _showFilters() {
    final provider = context.read<WarehouseProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => WarehouseFilterBottomSheet(
        provider: provider,
        onClearSearch: () {
          _searchController.clear();
          provider.fetchWarehouses(searchQuery: '');
        },
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              onSubmitted: (val) {
                context.read<WarehouseProvider>().fetchWarehouses(
                  searchQuery: val.trim(),
                );
              },
              decoration: InputDecoration(
                hintText: 'Search warehouses...',
                prefixIcon: IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedFilterHorizontal,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 18,
                  ),
                  onPressed: _showFilters,
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
                          context.read<WarehouseProvider>().fetchWarehouses(
                            searchQuery: '',
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

          Expanded(
            child: Consumer<WarehouseProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading && provider.warehouses.isEmpty) {
                  return ListShimmer.buildListShimmer(
                    context,
                    itemCount: 8,
                    type: ShimmerType.standard,
                  );
                }

                if (provider.error != null && provider.warehouses.isEmpty) {
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
                    onRefresh: _refreshWarehouses,
                    child: ListView(
                      children: [
                        const SizedBox(height: 48),
                        EmptyState(
                          title: title,
                          subtitle: subtitle,
                          lottieAsset: lottiePath,
                          actionLabel: 'Retry',
                          onAction: _refreshWarehouses,
                        ),
                      ],
                    ),
                  );
                }

                if (provider.warehouses.isEmpty) {
                  final hasSearch = _searchController.text.trim().isNotEmpty;

                  return ListView(
                    children: [
                      const SizedBox(height: 48),
                      EmptyState(
                        title: 'No warehouses found',
                        subtitle: hasSearch
                            ? 'Try adjusting your search'
                            : 'Warehouses will appear here',
                        lottieAsset: 'assets/lotties/empty ghost.json',
                        actionLabel: hasSearch ? 'Clear Search' : 'Refresh',
                        onAction: hasSearch
                            ? () {
                                _searchController.clear();
                                provider.fetchWarehouses(searchQuery: '');
                              }
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
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.warehouses.length,
                      itemBuilder: (context, index) {
                        final warehouse = provider.warehouses[index];
                        return WarehouseListTile(
                          key: ValueKey(warehouse.id),
                          warehouse: warehouse,
                          isDark: isDark,
                          onTap: () {
                            context.pushNamed(
                              AppRoutes.warehouseDetail,
                              extra: {'warehouseId': warehouse.id},
                            );
                          },
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
                    controller: _scrollController,
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
        ],
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
