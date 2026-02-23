import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../providers/location_provider.dart';
import '../widgets/location_list_tile.dart';
import '../widgets/location_filter_bottom_sheet.dart';
import '../widgets/location_group_tile.dart';
import '../models/location_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';

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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search locations...',
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
                          size: 20,
                        ),
                        onPressed: () => _searchController.clear(),
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
                _debounce?.cancel();
                context.read<LocationProvider>().fetchLocations(
                  searchQuery: value.trim(),
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

          Expanded(
            child: Consumer<LocationProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading && provider.locations.isEmpty) {
                  return ListShimmer.buildListShimmer(
                    context,
                    itemCount: 8,
                    type: ShimmerType.standard,
                  );
                }

                if (provider.error != null && provider.locations.isEmpty) {
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

                if (provider.locations.isEmpty) {
                  final hasSearch = _searchController.text.trim().isNotEmpty;
                  return ListView(
                    children: [
                      const SizedBox(height: 48),
                      EmptyState(
                        title: 'No locations found',
                        subtitle: hasSearch
                            ? 'Try adjusting your search'
                            : 'Locations will appear here',
                        lottieAsset: 'assets/lotties/empty ghost.json',
                        actionLabel: hasSearch ? 'Clear Search' : 'Refresh',
                        onAction: hasSearch
                            ? () {
                                _searchController.clear();
                                provider.fetchLocations(searchQuery: '');
                              }
                            : _onRefresh,
                      ),
                    ],
                  );
                }

                final groupBy = provider.selectedGroupBy;

                if (groupBy == null) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.locations.length,
                      itemBuilder: (context, index) {
                        final loc = provider.locations[index];
                        return LocationListTile(
                          key: ValueKey(loc.id),
                          location: loc,
                          isDark: isDark,
                          onTap: () {},
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
                    controller: _scrollController,
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
        ],
      ),
    );
  }

  void _showFilters() {
    final provider = context.read<LocationProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationFilterBottomSheet(
        provider: provider,
        onClearSearch: () => _searchController.clear(),
      ),
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

  Widget _buildActiveFiltersBadge(LocationProvider provider, ThemeData theme) {
    int count = 0;
    if (provider.usage.isNotEmpty && provider.usage != 'internal') count++;
    if (provider.parentId != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: count,
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
