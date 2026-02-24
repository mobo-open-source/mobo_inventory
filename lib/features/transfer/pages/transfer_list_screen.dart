import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../providers/transfer_provider.dart';
import '../widgets/transfer_list_tile.dart';
import '../widgets/transfer_filter_bottom_sheet.dart';
import '../utils/transfer_state_helper.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
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
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

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
    _searchDebouncer.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) {
        final provider = context.read<TransferProvider>();
        provider.fetchTransfers(
          searchQuery: _searchController.text.trim(),
          forceRefresh: true,
        );
        HapticsService.light();
      }
    });
  }

  Future<void> _refreshTransfers() async {
    final provider = context.read<TransferProvider>();
    await provider.fetchTransfers(forceRefresh: true);
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferFilterBottomSheet(
        provider: context.read<TransferProvider>(),
        onClearSearch: () => _searchController.clear(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final providerWatch = context.watch<TransferProvider>();
    final errLower = providerWatch.error?.toLowerCase() ?? '';
    final hideFab =
        errLower.contains('storage locations') || providerWatch.isLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  CustomSnackbar.showSuccess(context, message);
                  await context.read<TransferProvider>().fetchTransfers(
                    forceRefresh: true,
                  );
                }
              },
              backgroundColor: theme.primaryColor,
              tooltip: 'Create Transfer',
              child: Icon(HugeIcons.strokeRoundedFileAdd, color: Colors.white),
            ),
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
                hintText: 'Search transfers...',
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
              onSubmitted: (value) {
                _searchDebouncer.cancel();
                _searchDebouncer.run(() {
                  if (mounted) {
                    context.read<TransferProvider>().fetchTransfers(
                      searchQuery: value.trim(),
                      forceRefresh: true,
                    );
                    HapticsService.light();
                  }
                });
              },
            ),
          ),

          Consumer<TransferProvider>(
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
                              _buildGroupByPill(provider, theme),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (provider.transfers.length > 0 && !provider.isLoading)
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
            child: Consumer<TransferProvider>(
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
                  final errorText = provider.error!;
                  final errLower = errorText.toLowerCase();
                  final isModuleNotInstalled =
                      errLower.contains('module') &&
                      errLower.contains('not installed');
                  final isStorageDisabled = errLower.contains(
                    'storage locations',
                  );

                  final title = isStorageDisabled
                      ? 'Storage Locations disabled'
                      : (isModuleNotInstalled
                            ? 'Feature unavailable'
                            : 'Something went wrong');

                  final subtitle = isStorageDisabled
                      ? errorText
                      : (isModuleNotInstalled
                            ? 'This module is not installed on your server. Please contact your administrator.'
                            : 'Pull to refresh or tap retry');

                  final lottiePath = isModuleNotInstalled
                      ? 'assets/lotties/socialv no data.json'
                      : 'assets/lotties/Error 404.json';

                  return RefreshIndicator(
                    onRefresh: _refreshTransfers,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 48),
                        EmptyState(
                          title: title,
                          subtitle: subtitle,
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
                      provider.selectedStates.isNotEmpty ||
                      provider.startDate != null ||
                      provider.endDate != null ||
                      provider.selectedGroupBy != null ||
                      _searchController.text.trim().isNotEmpty;

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
                                          await provider.loadGroupTransfers(
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
                          onRefresh: _refreshTransfers,
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.groupSummary.length,
                            itemBuilder: (context, index) {
                              final groupKey = provider.groupSummary.keys
                                  .elementAt(index);
                              final count = provider.groupSummary[groupKey]!;
                              final isExpanded =
                                  _expandedGroups[groupKey] ?? false;
                              final loadedTransfers =
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
                                            loadedTransfers.isEmpty) {
                                          await provider.loadGroupTransfers(
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
                                          children: loadedTransfers
                                              .map(
                                                (item) => GestureDetector(
                                                  onTap: () {
                                                    context
                                                        .pushNamed(
                                                          AppRoutes
                                                              .transferDetail,
                                                          extra: item,
                                                        )
                                                        .then(
                                                          (_) => provider
                                                              .fetchTransfers(
                                                                forceRefresh:
                                                                    true,
                                                              ),
                                                        );
                                                  },
                                                  child: TransferListTile(
                                                    transfer: item,
                                                    isDark: isDark,
                                                  ),
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
                  onRefresh: _refreshTransfers,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.transfers.length,
                    itemBuilder: (context, index) {
                      final transfer = provider.transfers[index];
                      return GestureDetector(
                        onTap: () {
                          context
                              .pushNamed(
                                AppRoutes.transferDetail,
                                extra: transfer,
                              )
                              .then((_) {
                                provider.fetchTransfers(forceRefresh: true);
                              });
                        },
                        onLongPress: () async {
                          if (TransferStateHelper.canEdit(transfer.state)) {
                            final result = await context.pushNamed(
                              AppRoutes.transferForm,
                              extra: transfer,
                            );
                            if (!mounted) return;
                            if (result is Map && result['success'] == true) {
                              final message =
                                  result['message'] ??
                                  'Transfer updated successfully';
                              CustomSnackbar.showSuccess(context, message);
                              await provider.fetchTransfers(forceRefresh: true);
                            }
                          } else {
                            CustomSnackbar.showInfo(
                              context,
                              'Completed transfers cannot be edited',
                            );
                          }
                        },
                        child: TransferListTile(
                          transfer: transfer,
                          isDark: isDark,
                        ),
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
    int count = 0;
    if (provider.selectedStates.isNotEmpty) count++;
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
