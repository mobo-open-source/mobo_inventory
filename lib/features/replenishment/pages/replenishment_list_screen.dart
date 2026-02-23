import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/replenishment_provider.dart';
import '../../dashboard/providers/last_opened_provider.dart';
import '../widgets/replenishment_list_tile.dart';
import '../widgets/edit_orderpoint_values_sheet.dart';
import '../widgets/replenishment_filter_bottom_sheet.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../../../shared/widgets/loaders/list_shimmer.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../widgets/snooze_bottom_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/filters/active_filters_badge.dart';
import '../../../shared/widgets/filters/group_by_pill.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/services/haptics_service.dart';

import '../../../shared/widgets/app_bar_profile_actions.dart';

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
  final ScrollController _scrollController = ScrollController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);

  final Map<String, bool> _expandedGroups = {};
  bool _allGroupsExpanded = false;
  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(text: widget.initialSearchQuery);
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
    _scrollController.dispose();
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

  Future<void> _refresh() async {
    await context.read<ReplenishmentProvider>().fetch(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Consumer<ReplenishmentProvider>(
      builder: (context, provider, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
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
                  hintText: 'Search replenishment...',
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
                    onPressed: () {
                      final p = context.read<ReplenishmentProvider>();
                      Navigator.of(context, rootNavigator: true).push(
                        ModalBottomSheetRoute(
                          builder: (ctx) => ReplenishmentFilterBottomSheet(
                            provider: p,
                            onClearSearch: () => _searchController.clear(),
                          ),
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                        ),
                      );
                    },
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

                            final provider = context
                                .read<ReplenishmentProvider>();
                            provider.fetch(searchQuery: '', forceRefresh: true);
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
                  context.read<ReplenishmentProvider>().fetch(
                    searchQuery: value.trim(),
                    forceRefresh: true,
                  );
                },
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
                      if (provider.items.length > 0 && !provider.isLoading)
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
              child: Consumer<ReplenishmentProvider>(
                builder: (context, provider, _) {
                  if (!provider.isLoading &&
                      !provider.hasLoadedOnce &&
                      provider.error == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fetchData(provider);
                    });
                  }

                  if (!provider.hasLoadedOnce && provider.items.isEmpty) {
                    return ListShimmer.buildListShimmer(
                      context,
                      itemCount: 8,
                      type: ShimmerType.standard,
                    );
                  }

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
                      onRefresh: () => _refresh(),
                      child: ListView(
                        children: [
                          const SizedBox(height: 48),
                          EmptyState(
                            title: title,
                            subtitle: subtitle,
                            lottieAsset: lottiePath,
                            actionLabel: 'Retry',
                            onAction: () => _refresh(),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.items.isEmpty && provider.hasLoadedOnce) {
                    final hasActiveFilters =
                        provider.isGrouped ||
                        _searchController.text.trim().isNotEmpty;
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
                                  _searchController.clear();
                                  provider.clearFilters();
                                  await provider.fetch(forceRefresh: true);
                                }
                              : _refresh,
                        ),
                      ],
                    );
                  }

                  if (provider.isGrouped && provider.selectedGroupBy != null) {
                    final groups = <String, List<dynamic>>{};
                    for (final it in provider.items) {
                      String key = '';
                      switch (provider.selectedGroupBy) {
                        case 'location_id':
                          key = it.locationName.isNotEmpty
                              ? it.locationName
                              : 'Unknown Location';
                          break;
                        case 'product_id':
                          key = it.productName.isNotEmpty
                              ? it.productName
                              : 'Unknown Product';
                          break;
                        case 'product_category_id':
                          key = 'Category';
                          break;
                        default:
                          key = 'Other';
                      }
                      groups.putIfAbsent(key, () => []).add(it);
                    }
                    final keys = groups.keys.toList()..sort();

                    for (final k in keys) {
                      _expandedGroups.putIfAbsent(k, () => false);
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
                                '${keys.length} groups',
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
                                  if (!_allGroupsExpanded && keys.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          for (final k in keys) {
                                            _expandedGroups[k] = true;
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
                                  if (_expandedGroups.values.any((v) => v))
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          for (final k in keys) {
                                            _expandedGroups[k] = false;
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
                            onRefresh: _refresh,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: keys.length,
                              itemBuilder: (ctx, i) {
                                final k = keys[i];
                                final items = groups[k]!;
                                final isExpanded = _expandedGroups[k] ?? false;

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
                                            _expandedGroups[k] = !isExpanded;
                                            _allGroupsExpanded = _expandedGroups
                                                .values
                                                .every((v) => v);
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  k,
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
                                                  '${items.length}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            theme.primaryColor,
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
                                            children: items
                                                .map(
                                                  (e) => Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 6,
                                                        ),
                                                    child: ReplenishmentListTile(
                                                      item: e,
                                                      isDark: isDark,
                                                      onOrder: () async {
                                                        try {
                                                          await context
                                                              .read<
                                                                ReplenishmentProvider
                                                              >()
                                                              .actionReplenish(
                                                                ids: [e.id],
                                                                trigger:
                                                                    'manual',
                                                              );
                                                          if (context.mounted) {
                                                            CustomSnackbar.showSuccess(
                                                              context,
                                                              'Replenishment action queued for ${e.productName.isNotEmpty ? e.productName : 'item #${e.id}'}',
                                                            );
                                                          }
                                                        } catch (err) {
                                                          if (context.mounted) {
                                                            CustomSnackbar.showError(
                                                              context,
                                                              'Failed to trigger replenishment: $err',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      onAutomate: () async {
                                                        try {
                                                          final provider = context
                                                              .read<
                                                                ReplenishmentProvider
                                                              >();
                                                          await provider
                                                              .actionReplenishAuto(
                                                                ids: [e.id],
                                                                trigger:
                                                                    'manual',
                                                              );
                                                          if (!context.mounted)
                                                            return;
                                                          CustomSnackbar.showSuccess(
                                                            context,
                                                            'Auto-replenish queued for ${e.productName.isNotEmpty ? e.productName : 'item #${e.id}'}',
                                                          );
                                                          await provider.fetch(
                                                            forceRefresh: true,
                                                          );
                                                        } catch (err) {
                                                          if (context.mounted) {
                                                            CustomSnackbar.showError(
                                                              context,
                                                              'Failed to auto-replenish: $err',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      onSnooze: () async {
                                                        final res =
                                                            await SnoozeBottomSheet.show(
                                                              context,
                                                            );
                                                        if (res == null) return;
                                                        try {
                                                          final provider = context
                                                              .read<
                                                                ReplenishmentProvider
                                                              >();
                                                          await provider
                                                              .snoozeOrderpoints(
                                                                ids: [e.id],
                                                                predefinedDate:
                                                                    res.predefinedDate,
                                                                customDate: res
                                                                    .customDate,
                                                              );
                                                          if (!context.mounted)
                                                            return;
                                                          CustomSnackbar.showSuccess(
                                                            context,
                                                            res.predefinedDate ==
                                                                    'custom'
                                                                ? 'Snoozed until ${res.customDate!.toIso8601String().split('T').first}'
                                                                : 'Snoozed (${res.predefinedDate})',
                                                          );
                                                          await provider.fetch(
                                                            forceRefresh: true,
                                                          );
                                                        } catch (err) {
                                                          if (context.mounted) {
                                                            CustomSnackbar.showError(
                                                              context,
                                                              'Failed to snooze: $err',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      onEdit: () async {
                                                        final res =
                                                            await EditOrderpointValuesSheet.show(
                                                              context,
                                                              initialMin:
                                                                  e.minQty,
                                                              initialMax:
                                                                  e.maxQty,
                                                              initialToOrder:
                                                                  e.toOrder,
                                                            );
                                                        if (res == null) return;
                                                        try {
                                                          final provider = context
                                                              .read<
                                                                ReplenishmentProvider
                                                              >();
                                                          await provider
                                                              .updateOrderpointValues(
                                                                id: e.id,
                                                                minQty:
                                                                    res.minQty,
                                                                maxQty:
                                                                    res.maxQty,
                                                                manualToOrderQty:
                                                                    res.manualToOrderQty,
                                                              );
                                                          if (!context.mounted)
                                                            return;
                                                          CustomSnackbar.showSuccess(
                                                            context,
                                                            'Saved changes',
                                                          );
                                                        } catch (err) {
                                                          if (context.mounted) {
                                                            CustomSnackbar.showError(
                                                              context,
                                                              'Failed to save: $err',
                                                            );
                                                          }
                                                        }
                                                      },
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
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.items.length,
                      itemBuilder: (context, index) {
                        final item = provider.items[index];
                        return ReplenishmentListTile(
                          item: item,
                          isDark: isDark,
                          onOrder: () async {
                            try {
                              await context
                                  .read<ReplenishmentProvider>()
                                  .actionReplenish(
                                    ids: [item.id],
                                    trigger: 'manual',
                                  );
                              if (context.mounted) {
                                CustomSnackbar.showSuccess(
                                  context,
                                  'Replenishment action queued for ${item.productName.isNotEmpty ? item.productName : 'item #${item.id}'}',
                                );
                              }
                            } catch (err) {
                              if (context.mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to trigger replenishment: $err',
                                );
                              }
                            }
                          },
                          onAutomate: () async {
                            try {
                              final provider = context
                                  .read<ReplenishmentProvider>();
                              await provider.actionReplenishAuto(
                                ids: [item.id],
                                trigger: 'manual',
                              );
                              if (!context.mounted) return;
                              CustomSnackbar.showSuccess(
                                context,
                                'Auto-replenish queued for ${item.productName.isNotEmpty ? item.productName : 'item #${item.id}'}',
                              );
                              await provider.fetch(forceRefresh: true);
                            } catch (err) {
                              if (context.mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to auto-replenish: $err',
                                );
                              }
                            }
                          },
                          onSnooze: () async {
                            final res = await SnoozeBottomSheet.show(context);
                            if (res == null) return;
                            try {
                              final provider = context
                                  .read<ReplenishmentProvider>();
                              await provider.snoozeOrderpoints(
                                ids: [item.id],
                                predefinedDate: res.predefinedDate,
                                customDate: res.customDate,
                              );
                              if (!context.mounted) return;
                              CustomSnackbar.showSuccess(
                                context,
                                res.predefinedDate == 'custom'
                                    ? 'Snoozed until ${res.customDate!.toIso8601String().split('T').first}'
                                    : 'Snoozed (${res.predefinedDate})',
                              );
                              await provider.fetch(forceRefresh: true);
                            } catch (err) {
                              if (context.mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to snooze: $err',
                                );
                              }
                            }
                          },
                          onEdit: () async {
                            context
                                .read<LastOpenedProvider>()
                                .trackReplenishmentAccess(
                                  replenishmentId: item.id.toString(),
                                  productName: item.productName,
                                  locationName: item.locationName,
                                  data: item.toJson(),
                                );

                            final res = await EditOrderpointValuesSheet.show(
                              context,
                              initialMin: item.minQty,
                              initialMax: item.maxQty,
                              initialToOrder: item.toOrder,
                            );
                            if (res == null) return;
                            try {
                              final provider = context
                                  .read<ReplenishmentProvider>();
                              await provider.updateOrderpointValues(
                                id: item.id,
                                minQty: res.minQty,
                                maxQty: res.maxQty,
                                manualToOrderQty: res.manualToOrderQty,
                              );
                              if (!context.mounted) return;
                              CustomSnackbar.showSuccess(
                                context,
                                'Saved changes',
                              );
                            } catch (err) {
                              if (context.mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to save: $err',
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupByPill(ReplenishmentProvider provider, ThemeData theme) {
    final label = _groupByLabel(provider.selectedGroupBy);
    return GroupByPill(label: label, theme: theme);
  }

  String _groupByLabel(String? key) {
    switch (key) {
      case 'product_id':
        return 'Product';
      case 'location_id':
        return 'Location';
      default:
        return 'None';
    }
  }

  Widget _buildActiveFiltersBadge(
    ReplenishmentProvider provider,
    ThemeData theme,
  ) {
    int count = 0;

    if (_searchController.text.trim().isNotEmpty) count++;
    final hasGroupBy = provider.selectedGroupBy != null || provider.isGrouped;
    return ActiveFiltersBadge(
      count: count,
      theme: theme,
      hasGroupBy: hasGroupBy,
    );
  }
}
