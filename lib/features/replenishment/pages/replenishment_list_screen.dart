import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/replenishment_orderpoint.dart';
import '../providers/replenishment_provider.dart';
import '../services/replenishment_service.dart';
import '../utils/replenishment_error.dart';
import '../../../shared/widgets/mobo/mobo_button.dart';
import '../../dashboard/providers/last_opened_provider.dart';
import '../widgets/replenishment_list_tile.dart';
import '../widgets/edit_orderpoint_values_sheet.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../widgets/snooze_bottom_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';

import '../../../shared/widgets/app_bar_profile_actions.dart';
import '../../../core/services/error_manager.dart';
import '../../../core/theme/app_theme.dart';

/// A screen that displays a list of replenishment requirements (orderpoints).
///
/// Provides capabilities for searching, filtering, and grouping replenishment items,
/// as well as triggering manual or automatic replenishment actions and snoozing rules.
class ReplenishmentListScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const ReplenishmentListScreen({super.key, this.initialSearchQuery});

  @override
  State<ReplenishmentListScreen> createState() =>
      _ReplenishmentListScreenState();
}

class _ReplenishmentListScreenState extends State<ReplenishmentListScreen> {
  late final TextEditingController _searchController;
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;
  @override
  void initState() {
    super.initState();

    // Coming back from the dashboard's recent items, the provider may
    // already hold a search; show it so the box matches the list.
    _searchController = TextEditingController(
      text:
          widget.initialSearchQuery ??
          context.read<ReplenishmentProvider>().searchQuery,
    );
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ReplenishmentProvider>();
      _fetchData(provider);
    });
  }

  void _fetchData(ReplenishmentProvider provider) {
    if (widget.initialSearchQuery != null) {
      provider.fetch(
        searchQuery: widget.initialSearchQuery,
        forceRefresh: true,
      );
    } else if (provider.items.isEmpty && !provider.isLoading) {
      provider.fetch();
    }
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
      context.read<ReplenishmentProvider>().fetch(
        searchQuery: _searchController.text.trim(),
        forceRefresh: true,
      );
      HapticsService.light();
    });
  }

  bool _hasActiveFilter(ReplenishmentProvider provider) {
    return provider.isGrouped || _activeFilterCount(provider) > 0;
  }

  Future<void> _edit(ReplenishmentOrderpoint item) async {
    context.read<LastOpenedProvider>().trackReplenishmentAccess(
      replenishmentId: item.id.toString(),
      productName: item.productName,
      locationName: item.locationName,
      data: item.toJson(),
    );

    final provider = context.read<ReplenishmentProvider>();
    final res = await EditOrderpointValuesSheet.show(
      context,
      initialMin: item.minQty,
      initialMax: item.maxQty,
      initialToOrder: item.toOrder,
      initialLocationId: item.locationId,
      initialLocationName: item.locationName,
      loadLocations: () => provider.fetchLocations(companyId: item.companyId),
    );
    if (res == null || !mounted) return;
    try {
      await provider.updateOrderpointValues(
        id: item.id,
        minQty: res.minQty,
        maxQty: res.maxQty,
        manualToOrderQty: res.manualToOrderQty,
        locationId: res.locationId,
      );
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'Saved changes');
    } catch (err) {
      // e.g. "A replenishment rule already exists for this product on this
      // location." when moving the rule onto another rule's location.
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to save: ${ReplenishmentError.from(err).message}',
        );
      }
    }
  }

  Widget _tile(ReplenishmentOrderpoint item, bool isDark) {
    return ReplenishmentListTile(
      item: item,
      isDark: isDark,
      onOrder: () => _order(item),
      onAutomate: () => _automate(item),
      onSnooze: () => _snooze(item),
      onEdit: () => _edit(item),
    );
  }

  Future<void> _refresh() async {
    await context.read<ReplenishmentProvider>().fetch(forceRefresh: true);
  }

  /// Odoo's "Order" button for one orderpoint.
  Future<void> _order(ReplenishmentOrderpoint item) =>
      _runReplenishment(item, automate: false);

  /// Odoo's "Automate" button: switches the orderpoint to automatic and
  /// orders now, in one step.
  Future<void> _automate(ReplenishmentOrderpoint item) =>
      _runReplenishment(item, automate: true);

  Future<void> _runReplenishment(
    ReplenishmentOrderpoint item, {
    required bool automate,
  }) async {
    final provider = context.read<ReplenishmentProvider>();
    final productLabel = item.productName.isNotEmpty
        ? item.productName
        : 'item #${item.id}';

    try {
      final orderName = automate
          ? await provider.actionReplenishAuto(ids: [item.id])
          : await provider.actionReplenish(ids: [item.id]);
      if (!mounted) return;

      final done = automate
          ? 'Replenishment automated for $productLabel'
          : 'Replenishment ordered for $productLabel';
      CustomSnackbar.showSuccess(
        context,
        orderName != null ? '$done — $orderName created' : done,
      );
    } catch (err) {
      if (!mounted) return;
      await _showReplenishmentError(ReplenishmentError.from(err));
    } finally {
      // Odoo recomputes every quantity as part of the call (and deletes an
      // emptied manual orderpoint), so the list is stale either way. Without
      // this, a successful Order left the same "To Order" figure on screen,
      // inviting a second tap and a duplicate purchase line.
      if (mounted) await provider.fetch(forceRefresh: true);
    }
  }

  /// Odoo's "Snooze" button: hides the orderpoint from this list until the
  /// chosen date.
  Future<void> _snooze(ReplenishmentOrderpoint item) async {
    final res = await SnoozeBottomSheet.show(context);
    if (res == null || !mounted) return;

    final provider = context.read<ReplenishmentProvider>();
    try {
      final until = await provider.snoozeOrderpoints(
        ids: [item.id],
        predefinedDate: res.predefinedDate,
        customDate: res.customDate,
      );
      if (!mounted) return;
      final date =
          '${until.year}-${until.month.toString().padLeft(2, '0')}-'
          '${until.day.toString().padLeft(2, '0')}';
      CustomSnackbar.showSuccess(context, 'Snoozed until $date');
    } catch (err) {
      if (!mounted) return;
      await _showReplenishmentError(
        ReplenishmentError.from(err),
        title: 'Cannot Snooze',
      );
    } finally {
      if (mounted) await provider.fetch(forceRefresh: true);
    }
  }

  /// Odoo's own reason (e.g. a missing route or vendor on the product), shown
  /// as a dialog rather than a truncated snackbar. There is deliberately no
  /// "Edit Product" button like the web client's: the app's product screen
  /// is view-only, so the fix has to be made in Odoo itself.
  Future<void> _showReplenishmentError(
    ReplenishmentError error, {
    String title = 'Cannot Replenish',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: StatusColors.red, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            error.message,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          MoboButton.filled(
            label: 'OK',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _groupByLabels = {
    'warehouse_id': 'Warehouse',
    'location_id': 'Location',
    'product_id': 'Product',
    'product_category_id': 'Category',
  };

  static const Map<String, String> _groupBySubtitles = {
    'warehouse_id': 'Group by warehouse',
    'location_id': 'Group by stock location',
    'product_id': 'Group by product',
    'product_category_id': 'Group by product category',
  };

  void _showFilterBottomSheet() {
    final provider = context.read<ReplenishmentProvider>();

    final statusGroup = FilterGroup(
      title: 'Status',
      options: [
        FilterOption(title: 'To Reorder', value: provider.toReorder),
        FilterOption(title: 'Include Snoozed', value: !provider.notSnoozed),
      ],
    );

    // Selecting both triggers, or neither, lists every rule.
    final triggerGroup = FilterGroup(
      title: 'Trigger',
      options: [
        FilterOption(title: 'Manual', value: provider.trigger == 'manual'),
        FilterOption(title: 'Auto', value: provider.trigger == 'auto'),
      ],
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: _groupByLabels.entries
          .map(
            (e) => FilterOption(
              title: e.value,
              subtitle: _groupBySubtitles[e.key],
              value: provider.selectedGroupBy == e.key,
            ),
          )
          .toList(),
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [statusGroup, triggerGroup],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        final manual = values['trigger_manual'] == true;
        final auto = values['trigger_auto'] == true;
        final trigger = manual == auto ? '' : (manual ? 'manual' : 'auto');

        String? groupBy;
        for (final e in _groupByLabels.entries) {
          if (values['group_by_${e.value.toLowerCase()}'] == true) {
            groupBy = e.key;
          }
        }

        _expandedGroups.clear();
        _allGroupsExpanded = false;
        provider.applyFilters(
          notSnoozed: values['status_include_snoozed'] != true,
          toReorder: values['status_to_reorder'] == true,
          trigger: trigger,
          groupBy: groupBy,
        );
      },
    );
  }

  /// The screen's own title bar (the shell shows none on this tab).
  ///
  /// With [inHeader] it is built to sit in the scrolling header on a short
  /// screen: the status bar is already cleared by the body's [SafeArea], and
  /// it must not tint itself as "scrolled under" when the list scrolls.
  AppBar _buildAppBar(bool isDark, ThemeData theme, {bool inHeader = false}) {
    return AppBar(
      primary: !inHeader,
      notificationPredicate: inHeader
          ? (_) => false
          : defaultScrollNotificationPredicate,
      // Matches the shell's app bar on the other tabs, which is shorter in
      // compact landscape.
      toolbarHeight: isCompactHeight(context) ? 48 : null,
      automaticallyImplyLeading: false,
      title: Text(
        'Replenishment',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: const [AppBarProfileActions()],
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: isDark ? Colors.white : theme.primaryColor,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final compact = isCompactHeight(context);

    return Consumer<ReplenishmentProvider>(
      builder: (context, provider, _) => Scaffold(
        backgroundColor: Colors.transparent,
        // On a short screen the title bar scrolls away with the list instead
        // of staying pinned (see the header below).
        appBar: compact ? null : _buildAppBar(isDark, theme),
        // Under the app bar this is a no-op (the bar already takes the status
        // bar). Without it, it keeps the list from scrolling up beneath the
        // status bar.
        body: SafeArea(
          left: false,
          right: false,
          bottom: false,
          child: CollapsibleHeaderLayout(
            header: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compact) _buildAppBar(isDark, theme, inHeader: true),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.scaffoldBackgroundColor,
                  child: MoboSearchFilterBar(
                    controller: _searchController,
                    hintText: 'Search replenishment...',
                    hasActiveFilter: _hasActiveFilter(provider),
                    onFilterTap: _showFilterBottomSheet,
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                Consumer<ReplenishmentProvider>(
                  builder: (context, provider, _) {
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
                                    _buildGroupByPill(provider, theme),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // A grouped list pages its groups, as Odoo's
                          // pager does; each group carries its own count.
                          if (provider.isGrouped) ...[
                            if (provider.groups.isNotEmpty)
                              PaginationControls(
                                canGoToPreviousPage: false,
                                canGoToNextPage: false,
                                onPreviousPage: () {},
                                onNextPage: () {},
                                paginationText: PaginationControls.groupsText(
                                  provider.groups.length,
                                ),
                                isDark: isDark,
                                theme: theme,
                              ),
                          ] else if (provider.items.isNotEmpty &&
                              !provider.isLoading)
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

            body: Consumer<ReplenishmentProvider>(
              builder: (context, provider, _) {
                if (!provider.isLoading &&
                    !provider.hasLoadedOnce &&
                    provider.error == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _fetchData(provider);
                  });
                }

                if (!provider.hasLoadedOnce && provider.isEmpty) {
                  return ListShimmer.buildListShimmer(
                    context,
                    itemCount: 8,
                    type: ShimmerType.standard,
                  );
                }

                if (provider.isLoading && provider.isEmpty) {
                  return ListShimmer.buildListShimmer(
                    context,
                    itemCount: 8,
                    type: ShimmerType.standard,
                  );
                }

                if (provider.error != null && provider.isEmpty) {
                  final info = ErrorManager.analyzeError(provider.error!);
                  final lottiePath = info.type == ErrorType.moduleNotInstalled
                      ? 'assets/lotties/socialv no data.json'
                      : 'assets/lotties/Error 404.json';

                  return RefreshIndicator(
                    onRefresh: () => _refresh(),
                    child: ListView(
                      children: [
                        const SizedBox(height: 48),
                        EmptyState(
                          title: info.title,
                          subtitle: info.message,
                          lottieAsset: lottiePath,
                          actionLabel: 'Retry',
                          onAction: () => _refresh(),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.isEmpty && provider.hasLoadedOnce) {
                  final hasActiveFilters = _hasActiveFilter(provider);
                  return ListView(
                    children: [
                      const SizedBox(height: 48),
                      EmptyState(
                        title: 'No replenishment items',
                        subtitle: hasActiveFilters
                            ? 'Try adjusting your filters'
                            : 'Replenishment rules will appear here',
                        lottieAsset: 'assets/lotties/empty ghost.json',
                        actionLabel: hasActiveFilters
                            ? 'Clear All Filters'
                            : 'Refresh',
                        onAction: hasActiveFilters
                            ? () async {
                                _searchController.removeListener(
                                  _onSearchChanged,
                                );
                                _searchController.clear();
                                _searchController.addListener(_onSearchChanged);
                                provider.clearFilters();
                                await provider.fetch(forceRefresh: true);
                              }
                            : _refresh,
                      ),
                    ],
                  );
                }

                if (provider.isGrouped) {
                  return _buildGroupedList(
                    provider,
                    isDark,
                    theme,
                    compact: compact,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.items.length,
                    itemBuilder: (context, index) {
                      return _tile(provider.items[index], isDark);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupByPill(ReplenishmentProvider provider, ThemeData theme) {
    final label = _groupByLabel(provider.selectedGroupBy);
    return GroupByPill(label: label, theme: theme);
  }

  String _groupByLabel(String? key) => _groupByLabels[key] ?? 'None';

  int _activeFilterCount(ReplenishmentProvider provider) {
    int count = provider.activeFilterCount;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  /// The grouped list, with its "N groups · N rules / Expand All" row pinned
  /// above it — or, when [compact], as its first item so the row scrolls
  /// away with the header.
  Widget _buildGroupedList(
    ReplenishmentProvider provider,
    bool isDark,
    ThemeData theme, {
    required bool compact,
  }) {
    final groups = provider.groups;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final summary = Padding(
      padding: compact
          ? const EdgeInsets.only(bottom: 4)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${groups.length} groups · ${provider.totalCount} rules',
              style: TextStyle(
                color: mutedColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _allGroupsExpanded = !_allGroupsExpanded;
                for (final g in groups) {
                  _expandedGroups[g.key] = _allGroupsExpanded;
                }
              });
            },
            icon: Icon(
              _allGroupsExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(_allGroupsExpanded ? 'Collapse All' : 'Expand All'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );

    final groupList = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, compact ? 8 : 0, 16, 16),
        itemCount: groups.length + (compact ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (compact && i == 0) return summary;
          final group = groups[compact ? i - 1 : i];
          return _buildGroupCard(provider, group, isDark, theme);
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

  Widget _buildGroupCard(
    ReplenishmentProvider provider,
    ReplenishmentGroup group,
    bool isDark,
    ThemeData theme,
  ) {
    final isExpanded = _expandedGroups[group.key] ?? false;
    final items = provider.itemsForGroup(group.key);

    // Rows load when a group is first shown open (ListView builds only the
    // visible cards, so "Expand All" does not fire one request per group).
    final failed = provider.isGroupFailed(group.key);
    if (isExpanded &&
        items == null &&
        !failed &&
        !provider.isGroupLoading(group.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.loadGroup(group.key);
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              setState(() {
                _expandedGroups[group.key] = !isExpanded;
                _allGroupsExpanded = provider.groups.every(
                  (g) => _expandedGroups[g.key] ?? false,
                );
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.label,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  StatusColors.buildStatusBadge(
                    '${group.count}',
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: failed
                  ? TextButton.icon(
                      onPressed: () => provider.loadGroup(group.key),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Couldn't load this group. Retry"),
                    )
                  : items == null
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ...items.map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _tile(e, isDark),
                          ),
                        ),
                        if (group.count > items.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Showing ${items.length} of ${group.count}. '
                              'Search or filter to narrow this group.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBadge(
    ReplenishmentProvider provider,
    ThemeData theme,
  ) {
    final hasGroupBy = provider.selectedGroupBy != null || provider.isGrouped;
    return ActiveFiltersBadge(
      count: _activeFilterCount(provider),
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }
}
