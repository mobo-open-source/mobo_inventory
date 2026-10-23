import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/location_provider.dart';
import '../widgets/location_list_tile.dart';
import '../widgets/location_group_tile.dart';
import '../models/location_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/error_manager.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';

/// A screen displaying a hierarchical list of stock locations.
///
/// Supports searching, filtering by usage type (internal, customer, etc.),
/// and grouping by parent location or name for efficient navigation.
class LocationListScreen extends StatefulWidget {
  final String title;
  final String initialUsage;
  final int? parentLocationId;
  final bool asTab;

  const LocationListScreen({
    super.key,
    required this.title,
    this.initialUsage = 'internal',
    this.parentLocationId,
    this.asTab = false,
  });

  @override
  State<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LocationProvider>();
      provider.fetchLocations(
        usage: widget.initialUsage,
        parentId: widget.parentLocationId,
      );
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
      if (!mounted) return;
      final provider = context.read<LocationProvider>();
      provider.fetchLocations(searchQuery: _searchController.text.trim());
    });
  }

  Future<void> _onRefresh() async {
    await context.read<LocationProvider>().refresh();
  }

  void _clearAllFilters() {
    _searchController.clear();
    final provider = context.read<LocationProvider>();
    provider.clearFilters();
    provider.fetchLocations(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.asTab
          ? null
          : AppBar(
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
      body: CollapsibleHeaderLayout(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: Consumer<LocationProvider>(
                builder: (_, provider, __) {
                  return MoboSearchFilterBar(
                    controller: _searchController,
                    hintText: 'Search locations...',
                    hasActiveFilter: _activeFilterCount(provider) > 0,
                    onFilterTap: _showFilterBottomSheet,
                    onChanged: (_) => setState(() {}),
                  );
                },
              ),
            ),

            Consumer<LocationProvider>(
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
                      if (provider.totalCount > 0 &&
                          provider.locations.isNotEmpty)
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

        body: Consumer<LocationProvider>(
          builder: (_, provider, __) {
            if (provider.isLoading && provider.locations.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.error != null && provider.locations.isEmpty) {
              final info = ErrorManager.analyzeError(provider.error!);
              final lottiePath = info.type == ErrorType.moduleNotInstalled
                  ? 'assets/lotties/socialv no data.json'
                  : 'assets/lotties/Error 404.json';

              return EmptyState(
                title: info.title,
                subtitle: info.message,
                lottieAsset: lottiePath,
                actionLabel: 'Retry',
                onAction: _onRefresh,
              );
            }

            if (provider.locations.isEmpty) {
              final hasActiveFilters =
                  _activeFilterCount(provider) > 0 ||
                  provider.selectedGroupBy != null;
              return ListView(
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    title: 'No locations found',
                    subtitle: hasActiveFilters
                        ? 'Try adjusting your filters'
                        : 'Locations will appear here',
                    lottieAsset: 'assets/lotties/empty ghost.json',
                    actionLabel: hasActiveFilters
                        ? 'Clear All Filters'
                        : 'Refresh',
                    onAction: hasActiveFilters ? _clearAllFilters : _onRefresh,
                  ),
                ],
              );
            }

            final groupBy = provider.selectedGroupBy;

            if (groupBy == null) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.locations.length,
                  itemBuilder: (context, index) {
                    final loc = provider.locations[index];
                    return LocationListTile(
                      key: ValueKey(loc.id),
                      location: loc,
                      isDark: isDark,
                    );
                  },
                ),
              );
            }

            final groups = _buildGroups(provider.locations, groupBy);
            final keys = groups.keys.toList()..sort();
            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final key = keys[index];
                  final items = groups[key]!;
                  return LocationGroupTile(
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

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilterBottomSheet() {
    final provider = context.read<LocationProvider>();

    const usages = <String>[
      'internal',
      'view',
      'customer',
      'supplier',
      'inventory',
      'production',
      'transit',
    ];

    final usageGroup = FilterGroup(
      title: 'Location Usage',
      options: usages
          .map(
            (u) => FilterOption(
              title: u[0].toUpperCase() + u.substring(1),
              value: provider.usage == u,
            ),
          )
          .toList(),
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: [
        FilterOption(
          title: 'Usage',
          subtitle: 'Group by location type',
          value: provider.selectedGroupBy == 'usage',
        ),
        FilterOption(
          title: 'Parent',
          subtitle: 'Group by parent location',
          value: provider.selectedGroupBy == 'parent',
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
      filterGroups: [usageGroup],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        // `usage` is single-select in the old UI (a tap on a chip just
        // selected that usage; there was no way to deselect). The shared
        // widget renders these as independent checkboxes, so if more than
        // one somehow comes back true we take the first match, and if
        // none are true we fall back to the default 'internal' usage —
        // mirroring the old widget's exclusivity behaviour.
        String? selectedUsage;
        for (final u in usages) {
          final title = u[0].toUpperCase() + u.substring(1);
          if (values['location_usage_${_snake(title)}'] == true) {
            selectedUsage = u;
            break;
          }
        }
        selectedUsage ??= 'internal';

        String? groupBy;
        if (values['group_by_usage'] == true) {
          groupBy = 'usage';
        } else if (values['group_by_parent'] == true) {
          groupBy = 'parent';
        } else if (values['group_by_name_(a-z)'] == true) {
          groupBy = 'name:letter';
        }

        provider.setGroupBy(groupBy);
        provider.fetchLocations(usage: selectedUsage, forceRefresh: true);
      },
    );
  }

  Widget _buildGroupByPill(ThemeData theme, String? groupBy) {
    if (groupBy == null) return const SizedBox.shrink();
    String label;
    switch (groupBy) {
      case 'usage':
        label = 'Usage';
        break;
      case 'parent':
        label = 'Parent';
        break;
      case 'name:letter':
        label = 'Name (A–Z)';
        break;
      default:
        label = 'Custom';
    }
    return GroupByPill(label: label, theme: theme);
  }

  int _activeFilterCount(LocationProvider provider) {
    int count = 0;
    if (provider.usage.isNotEmpty && provider.usage != 'internal') count++;
    if (provider.parentId != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  Widget _buildActiveFiltersBadge(LocationProvider provider, ThemeData theme) {
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: _activeFilterCount(provider),
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }

  Map<String, List<StockLocation>> _buildGroups(
    List<StockLocation> items,
    String groupBy,
  ) {
    final map = <String, List<StockLocation>>{};
    for (final loc in items) {
      String key;
      switch (groupBy) {
        case 'usage':
          key = loc.usage;
          break;
        case 'parent':
          key = (loc.parentName?.trim().isNotEmpty ?? false)
              ? (loc.parentName!)
              : 'No parent';
          break;
        case 'name:letter':
          final first = (loc.name.trim().isNotEmpty
              ? loc.name.trim()[0].toUpperCase()
              : '#');
          key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
          break;
        default:
          key = 'Other';
      }
      map.putIfAbsent(key, () => []).add(loc);
    }
    return map;
  }
}
