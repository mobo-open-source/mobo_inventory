import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../models/transfer_model.dart';
import '../providers/transfer_provider.dart';
import '../widgets/transfer_list_tile.dart';
import '../utils/transfer_state_helper.dart';
import '../../../shared/widgets/filters/premium_filter_bottom_sheet.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/access_rights_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/services/error_manager.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';
import '../../../shared/widgets/search/mobo_search_filter_bar.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';

/// Screen displaying a searchable and filterable list of internal stock transfers.
class TransferListScreen extends StatefulWidget {
  const TransferListScreen({super.key});

  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends State<TransferListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  /// Groups whose "Load more" is fetching.
  final Set<String> _loadingMoreGroups = {};

  /// Whether the user may edit transfers, as of the last build.
  bool _canEditRights = false;

  late final TransferProvider _provider;

  /// The provider's search query as of the last [_syncSearchField], so only
  /// a change of it is acted on.
  String _syncedQuery = '';

  /// The query this screen last searched for, so the provider echoing it
  /// back is not mistaken for an outside change.
  String? _sentQuery;

  @override
  void initState() {
    super.initState();
    _provider = context.read<TransferProvider>();
    // Show the search the list is already filtered by, if any.
    _syncedQuery = _provider.searchQuery;
    _searchController.text = _syncedQuery;
    _searchController.addListener(_onSearchChanged);
    _provider.addListener(_syncSearchField);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TransferProvider>();
      _fetchData(provider);
    });
  }

  void _fetchData(TransferProvider provider) {
    provider.fetchTransfers();

    if (provider.selectedGroupBy != null) {
      provider.fetchGroupSummary();
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_syncSearchField);
    _searchDebouncer.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) _search();
    });
  }

  /// Searches for what the field holds, under the filters already applied.
  void _search() {
    final provider = context.read<TransferProvider>();
    final query = _searchController.text.trim();
    // The field also notifies on a cursor move or a focus change; only a
    // different text is a new search (and a reload of the list).
    if (query == provider.searchQuery) return;

    _sentQuery = query;
    provider.fetchTransfers(
      searchQuery: query,
      // The date range would otherwise be dropped by a new search.
      startDate: provider.startDate,
      endDate: provider.endDate,
      forceRefresh: true,
    );
    // A grouped list shows its groups, not `transfers`: their counts and
    // records are searched too, or clearing the search would leave them on
    // the old result.
    if (provider.isGrouped) provider.fetchGroupSummary();
    HapticsService.light();
  }

  /// Keeps the search field showing the query the list is filtered by when
  /// something else changes it — e.g. the dashboard's Internal Transfers card
  /// clears this tab's filters and search. The screen's own searches are
  /// left alone, so the field never fights the user while they type.
  void _syncSearchField() {
    final query = _provider.searchQuery;
    if (query == _syncedQuery) return;
    _syncedQuery = query;
    if (query == _sentQuery || query == _searchController.text.trim()) return;

    void apply() {
      if (!mounted || _provider.searchQuery != query) return;
      _searchDebouncer.cancel();
      // Not a new search: don't let the listener fetch again.
      _searchController.removeListener(_onSearchChanged);
      _searchController.text = query;
      _searchController.addListener(_onSearchChanged);
      _sentQuery = null;
    }

    // Changing the text rebuilds the search bar, which can't happen while a
    // frame is being built.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// Reloads with the filters already applied (and shown) kept as they are
  /// — and, when grouped, the groups' counts and records with them.
  Future<void> _refreshTransfers() async {
    final provider = context.read<TransferProvider>();
    await provider.fetchTransfers(forceRefresh: true, updateFilters: false);
    if (provider.isGrouped) await provider.fetchGroupSummary();
  }

  void _openTransfer(InternalTransfer transfer) {
    context.pushNamed(AppRoutes.transferDetail, extra: transfer).then((_) {
      if (mounted) _refreshTransfers();
    });
  }

  /// Long press: opens the transfer's form, if it may still be edited.
  Future<void> _editTransfer(InternalTransfer transfer) async {
    if (!TransferStateHelper.canEdit(transfer.state)) {
      CustomSnackbar.showInfo(context, 'Completed transfers cannot be edited');
      return;
    }
    if (!_canEditRights) {
      CustomSnackbar.showInfo(
        context,
        "You don't have permission to edit transfers",
      );
      return;
    }
    final result = await context.pushNamed(
      AppRoutes.transferForm,
      extra: transfer,
    );
    if (!mounted) return;
    if (result is Map && result['success'] == true) {
      final message = result['message'] ?? 'Transfer updated successfully';
      CustomSnackbar.showSuccess(context, message);
      await _refreshTransfers();
    }
  }

  // Maps the internal Odoo state code to the human-readable label shown as
  // a chip in the shared filter bottom sheet.
  static const Map<String, String> _stateLabels = {
    'draft': 'Draft',
    'waiting': 'Waiting Another Operation',
    'confirmed': 'Waiting',
    'assigned': 'Ready',
    'done': 'Done',
    'cancel': 'Cancelled',
  };

  // Maps the internal group-by field to the label shown in the "Group By"
  // tab (mirrors the options offered by the old GroupBySelector, minus
  // 'None' which the shared widget already provides on its own).
  static const Map<String, String> _groupByFieldLabels = {
    'state': 'Status',
    'date': 'Date',
    'priority': 'Priority',
  };

  static const Map<String, String> _groupBySubtitles = {
    'state': 'Group by transfer status',
    'date': 'Group by scheduled date',
    'priority': 'Group by normal or urgent',
  };

  static String _snake(String s) => s.toLowerCase().replaceAll(' ', '_');

  void _showFilterBottomSheet() {
    final provider = context.read<TransferProvider>();

    final statusGroup = FilterGroup(
      title: 'Status',
      options: _stateLabels.entries
          .map(
            (entry) => FilterOption(
              title: entry.value,
              value: provider.selectedStates.contains(entry.key),
            ),
          )
          .toList(),
    );

    final dateRangeGroup = FilterGroup(
      title: 'Date Range',
      options: [
        FilterOption(
          title: 'Start Date',
          value: provider.startDate != null,
          selectedValue: provider.startDate,
        ),
        FilterOption(
          title: 'End Date',
          value: provider.endDate != null,
          selectedValue: provider.endDate,
        ),
      ],
    );

    final groupByGroup = FilterGroup(
      title: 'Group By',
      options: _groupByFieldLabels.entries
          .map(
            (entry) => FilterOption(
              title: entry.value,
              subtitle: _groupBySubtitles[entry.key],
              value: provider.selectedGroupBy == entry.key,
            ),
          )
          .toList(),
    );

    PremiumFilterBottomSheet.show(
      context: context,
      title: 'Filter & Group By',
      filterGroups: [statusGroup, dateRangeGroup],
      groupByOptions: [groupByGroup],
      onApply: (values) {
        final selectedStates = _stateLabels.entries
            .where((entry) => values['status_${_snake(entry.value)}'] == true)
            .map((entry) => entry.key)
            .toList();

        final startDate = values['date_range_start_date_value'] as DateTime?;
        final endDate = values['date_range_end_date_value'] as DateTime?;

        String? groupBy;
        for (final entry in _groupByFieldLabels.entries) {
          if (values['group_by_${_snake(entry.value)}'] == true) {
            groupBy = entry.key;
            break;
          }
        }

        provider.setGroupBy(groupBy);
        provider.fetchTransfers(
          // Keep the search the field shows.
          searchQuery: _searchController.text.trim(),
          states: selectedStates,
          startDate: startDate,
          endDate: endDate,
          updateFilters: true,
        );
        if (groupBy != null) {
          provider.fetchGroupSummary();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final providerWatch = context.watch<TransferProvider>();
    final errLower = providerWatch.error?.toLowerCase() ?? '';
    final access = context.watch<AccessRightsService>();
    // Asked here, during the build, so the answer arrives (and rebuilds)
    // before a long press needs it.
    _canEditRights = TransferStateHelper.hasEditRights(access);
    final hideFab =
        errLower.contains('storage location') ||
        providerWatch.isLoading ||
        !TransferStateHelper.hasCreateRights(access);
    final compact = isCompactHeight(context);
    // Room under the last row so it can scroll clear of the FAB.
    final listBottomPadding = hideFab ? 16.0 : _fabClearance;

    return Scaffold(
      floatingActionButton: hideFab
          ? null
          : FloatingActionButton(
              heroTag: 'createTransferFab',
              onPressed: () async {
                final result = await context.pushNamed(AppRoutes.transferForm);
                if (!mounted) return;

                if (result is Map && result['success'] == true) {
                  final message =
                      result['message'] ?? 'Transfer created successfully';
                  if (result['warning'] == true) {
                    CustomSnackbar.showWarning(context, message);
                  } else {
                    CustomSnackbar.showSuccess(context, message);
                  }
                  await context.read<TransferProvider>().fetchTransfers(
                    forceRefresh: true,
                    updateFilters: false,
                  );
                }
              },
              backgroundColor: theme.primaryColor,
              tooltip: 'Create Transfer',
              child: Icon(HugeIcons.strokeRoundedFileAdd, color: Colors.white),
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
                hintText: 'Search transfers...',
                hasActiveFilter: _activeFilterCount(providerWatch) > 0,
                onFilterTap: _showFilterBottomSheet,
                onChanged: (_) => setState(() {}),
              ),
            ),

            Consumer<TransferProvider>(
              builder: (context, provider, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
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
                      ..._buildPager(provider, isDark, theme),
                    ],
                  ),
                );
              },
            ),
          ],
        ),

        body: Consumer<TransferProvider>(
          builder: (context, provider, child) {
            if (!provider.isLoading &&
                !provider.hasLoadedOnce &&
                provider.error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchData(provider);
              });
            }

            if (!provider.hasLoadedOnce && provider.transfers.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.isLoading && provider.transfers.isEmpty) {
              return ListShimmer.buildListShimmer(
                context,
                itemCount: 8,
                type: ShimmerType.standard,
              );
            }

            if (provider.error != null && provider.transfers.isEmpty) {
              // TransferProvider already resolves its own errors to a
              // finished, user-facing message (either via
              // OdooErrorMapper, or a specific setup message when the
              // "Storage Locations" setting is off and the "Internal
              // Transfers" operation type is unavailable) —
              // re-classifying that finished text through
              // ErrorManager.analyzeError just discards it, since plain
              // text never matches its exception-shaped patterns and
              // falls back to a generic "Server Error". Show the
              // setup message directly instead.
              final isOperationTypeIssue = provider.error!
                  .toLowerCase()
                  .contains('storage location');

              String title;
              String message;
              String lottiePath;
              if (isOperationTypeIssue) {
                title = 'Setup Required';
                message = provider.error!;
                lottiePath = 'assets/lotties/Error 404.json';
              } else {
                final info = ErrorManager.analyzeError(provider.error!);
                title = info.title;
                message = info.message;
                lottiePath = info.type == ErrorType.moduleNotInstalled
                    ? 'assets/lotties/socialv no data.json'
                    : 'assets/lotties/Error 404.json';
              }

              return RefreshIndicator(
                onRefresh: _refreshTransfers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    EmptyState(
                      title: title,
                      subtitle: message,
                      lottieAsset: lottiePath,
                      actionLabel: 'Retry',
                      onAction: _refreshTransfers,
                    ),
                  ],
                ),
              );
            }

            if (provider.transfers.isEmpty && provider.hasLoadedOnce) {
              final hasActiveFilters =
                  _activeFilterCount(provider) > 0 ||
                  provider.selectedGroupBy != null;

              return RefreshIndicator(
                onRefresh: _refreshTransfers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    EmptyState(
                      title: 'No transfers found',
                      subtitle: hasActiveFilters
                          ? 'Try adjusting your filters'
                          : 'Create your first transfer to get started',
                      lottieAsset: 'assets/lotties/empty ghost.json',
                      actionLabel: hasActiveFilters
                          ? 'Clear All Filters'
                          : 'Refresh',
                      onAction: hasActiveFilters
                          ? _clearAllFilters
                          : _refreshTransfers,
                    ),
                  ],
                ),
              );
            }

            if (provider.selectedGroupBy != null) {
              if (provider.isLoading && provider.groupSummary.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshTransfers,
                  child: SingleChildScrollView(
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
                  ),
                );
              }

              // A group the search (or a filter) dropped is no longer open:
              // it would otherwise come back open but empty.
              _expandedGroups.removeWhere(
                (key, _) => !provider.groupSummary.containsKey(key),
              );
              for (final groupKey in provider.groupSummary.keys) {
                _expandedGroups.putIfAbsent(groupKey, () => false);
              }
              _allGroupsExpanded =
                  _expandedGroups.isNotEmpty &&
                  _expandedGroups.values.every((expanded) => expanded);

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
                      provider.groupSummary.length == 1
                          ? '1 group'
                          : '${provider.groupSummary.length} groups',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                                for (final key in provider.groupSummary.keys) {
                                  _expandedGroups[key] = true;
                                }
                                _allGroupsExpanded = true;
                              });

                              for (final key in provider.groupSummary.keys) {
                                if (provider.loadedGroups[key] == null ||
                                    provider.loadedGroups[key]!.isEmpty) {
                                  await provider.loadGroupTransfers(key);
                                }
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
                                for (final key in provider.groupSummary.keys) {
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
                onRefresh: _refreshTransfers,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compact ? 8 : 16,
                    16,
                    listBottomPadding,
                  ),
                  itemCount: provider.groupSummary.length + (compact ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (compact && index == 0) return summary;
                    final groupKey = provider.groupSummary.keys.elementAt(
                      compact ? index - 1 : index,
                    );
                    final count = provider.groupSummary[groupKey]!;
                    final isExpanded = _expandedGroups[groupKey] ?? false;
                    final loadedTransfers =
                        provider.loadedGroups[groupKey] ?? [];

                    // §12 grouped section header shell.
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
                            onTap: () async {
                              setState(() {
                                _expandedGroups[groupKey] = !isExpanded;
                              });
                              if (!isExpanded && loadedTransfers.isEmpty) {
                                await provider.loadGroupTransfers(groupKey);
                                if (mounted) setState(() {});
                              }
                            },
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      groupKey,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  StatusColors.buildStatusBadge(
                                    '$count',
                                    theme.primaryColor,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
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
                                children: [
                                  for (final item in loadedTransfers)
                                    GestureDetector(
                                      onTap: () => _openTransfer(item),
                                      child: TransferListTile(
                                        transfer: item,
                                        isDark: isDark,
                                      ),
                                    ),
                                  if (loadedTransfers.isNotEmpty &&
                                      loadedTransfers.length < count)
                                    _buildGroupLoadMore(
                                      provider,
                                      groupKey,
                                      count - loadedTransfers.length,
                                    ),
                                ],
                              ),
                            ),
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
              onRefresh: _refreshTransfers,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding),
                itemCount: provider.transfers.length,
                itemBuilder: (context, index) {
                  final transfer = provider.transfers[index];
                  return GestureDetector(
                    onTap: () => _openTransfer(transfer),
                    onLongPress: () => _editTransfer(transfer),
                    child: TransferListTile(transfer: transfer, isDark: isDark),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Load more" at the foot of an expanded group showing fewer transfers
  /// than its count.
  Widget _buildGroupLoadMore(
    TransferProvider provider,
    String groupKey,
    int remaining,
  ) {
    final loading = _loadingMoreGroups.contains(groupKey);
    return TextButton(
      onPressed: loading
          ? null
          : () async {
              setState(() => _loadingMoreGroups.add(groupKey));
              await provider.loadMoreGroupTransfers(groupKey);
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

  /// Bottom padding for the list while the FAB is shown: the FAB (56) plus
  /// its 16px margin plus a 16px gap, so the last row scrolls clear of it.
  static const double _fabClearance = 88;

  /// The pager, as Odoo shows it: ungrouped it pages the transfers; a
  /// grouped list pages its groups (each group's header carries its own
  /// count).
  List<Widget> _buildPager(
    TransferProvider provider,
    bool isDark,
    ThemeData theme,
  ) {
    if (provider.isGrouped) {
      if (provider.groupSummary.isEmpty) return const [];
      return [
        const SizedBox(width: 8),
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
    if (provider.totalCount == 0 || provider.isLoading) return const [];
    return [
      const SizedBox(width: 8),
      PaginationControls(
        canGoToPreviousPage: provider.canGoToPreviousPage,
        canGoToNextPage: provider.canGoToNextPage,
        onPreviousPage: () => provider.goToPreviousPage(),
        onNextPage: () => provider.goToNextPage(),
        paginationText: provider.getPaginationText(),
        isDark: isDark,
        theme: theme,
      ),
    ];
  }

  Widget _buildGroupByPill(TransferProvider provider, ThemeData theme) {
    final label = _groupByLabel(provider.selectedGroupBy);
    return GroupByPill(label: label, theme: theme);
  }

  String _groupByLabel(String? key) {
    switch (key) {
      case 'state':
        return 'Status';
      case 'date':
        return 'Date';
      case 'priority':
        return 'Priority';
      default:
        return 'None';
    }
  }

  void _clearAllFilters() {
    final provider = context.read<TransferProvider>();
    _searchController.clear();
    provider.clearFilters();
    provider.fetchTransfers(forceRefresh: true);
  }

  Widget _buildActiveFiltersBadge(TransferProvider provider, ThemeData theme) {
    final hasGroupBy = provider.selectedGroupBy != null;
    return ActiveFiltersBadge(
      count: _activeFilterCount(provider),
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }

  /// Counts how many filters (including the search query) are currently
  /// active, used both for the active filters badge and the search bar's
  /// filter icon tint.
  int _activeFilterCount(TransferProvider provider) {
    int count = 0;
    if (provider.selectedStates.isNotEmpty) count++;
    if (provider.startDate != null) count++;
    if (provider.endDate != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }
}
