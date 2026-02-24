import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../shared/widgets/filters/filter_chip_widget.dart';
import '../providers/move_history_provider.dart';
import '../../../core/services/haptics_service.dart';
import '../../../shared/widgets/toggles/mobo_toggle.dart';

class MoveHistoryFilterBottomSheet extends StatefulWidget {
  final MoveHistoryProvider provider;
  final VoidCallback? onClearSearch;
  const MoveHistoryFilterBottomSheet({
    super.key,
    required this.provider,
    this.onClearSearch,
  });

  @override
  State<MoveHistoryFilterBottomSheet> createState() =>
      _MoveHistoryFilterBottomSheetState();
}

class _MoveHistoryFilterBottomSheetState
    extends State<MoveHistoryFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late List<String> _tempPickingTypeCodes;
  late DateTime? _tempStartDate;
  late DateTime? _tempEndDate;
  late String? _tempStatus;
  late String? _tempGroupBy;
  late bool _tempActiveOnly;
  late bool _tempInventoryOnly;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tempPickingTypeCodes = List.from(widget.provider.pickingTypeCodes);
    _tempStartDate = widget.provider.dateFrom;
    _tempEndDate = widget.provider.dateTo;
    _tempStatus = widget.provider.status;
    _tempGroupBy = widget.provider.selectedGroupBy;
    _tempActiveOnly = widget.provider.activeOnly;
    _tempInventoryOnly = widget.provider.inventoryOnly;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter & Group By',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorPadding: const EdgeInsets.all(4),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(height: 44, text: 'Filter'),
                  Tab(height: 44, text: 'Group By'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFilterTab(isDark, theme),
                  _buildGroupByTab(isDark, theme),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticsService.light();

                        widget.onClearSearch?.call();

                        if (mounted) Navigator.pop(context);

                        Future.microtask(() async {
                          widget.provider.clearFilters();
                          await widget.provider.fetchHistory();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticsService.success();
                        if (mounted) {
                          Navigator.pop(context);
                        }
                        widget.provider.setGroupBy(_tempGroupBy);

                        widget.provider.fetchHistory(
                          status: _tempStatus,
                          pickingTypeCodes: _tempPickingTypeCodes,
                          dateFrom: _tempStartDate,
                          dateTo: _tempEndDate,
                          activeOnly: _tempActiveOnly,
                          inventoryOnly: _tempInventoryOnly,
                          groupBy: _tempGroupBy,
                          updateFilters: true,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move Status',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterChipWidget(
                label: 'All',
                isSelected: _tempStatus == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _tempStatus = null;
                    });
                  }
                },
              ),
              FilterChipWidget(
                label: 'Done',
                isSelected: _tempStatus == 'done',
                onSelected: (selected) {
                  setState(() {
                    _tempStatus = selected ? 'done' : null;
                  });
                },
              ),
              FilterChipWidget(
                label: 'Cancelled',
                isSelected: _tempStatus == 'cancel',
                onSelected: (selected) {
                  setState(() {
                    _tempStatus = selected ? 'cancel' : null;
                  });
                },
              ),
              FilterChipWidget(
                label: 'Assigned',
                isSelected: _tempStatus == 'assigned',
                onSelected: (selected) {
                  setState(() {
                    _tempStatus = selected ? 'assigned' : null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Move Type',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterChipWidget(
                label: 'Outgoing',
                isSelected: _tempPickingTypeCodes.contains('outgoing'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _tempPickingTypeCodes.add('outgoing');
                    } else {
                      _tempPickingTypeCodes.remove('outgoing');
                    }
                  });
                },
              ),
              FilterChipWidget(
                label: 'Internal',
                isSelected: _tempPickingTypeCodes.contains('internal'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _tempPickingTypeCodes.add('internal');
                    } else {
                      _tempPickingTypeCodes.remove('internal');
                    }
                  });
                },
              ),
              FilterChipWidget(
                label: 'Incoming',
                isSelected: _tempPickingTypeCodes.contains('incoming'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _tempPickingTypeCodes.add('incoming');
                    } else {
                      _tempPickingTypeCodes.remove('incoming');
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Filter Options',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active Only'),
            subtitle: const Text('Show only active moves'),
            trailing: MoboToggle(
              value: _tempActiveOnly,
              onChanged: (val) {
                setState(() {
                  _tempActiveOnly = val;
                });
              },
            ),
            onTap: () {
              setState(() {
                _tempActiveOnly = !_tempActiveOnly;
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Inventory Only'),
            subtitle: const Text('Show only inventory moves'),
            trailing: MoboToggle(
              value: _tempInventoryOnly,
              onChanged: (val) {
                setState(() {
                  _tempInventoryOnly = val;
                });
              },
            ),
            onTap: () {
              setState(() {
                _tempInventoryOnly = !_tempInventoryOnly;
              });
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Date Range',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _tempStartDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _tempStartDate = date);
                    }
                  },
                  icon: const Icon(HugeIcons.strokeRoundedCalendar03, size: 16),
                  label: Text(
                    _tempStartDate != null
                        ? '${_tempStartDate!.day}/${_tempStartDate!.month}/${_tempStartDate!.year}'
                        : 'Start Date',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _tempEndDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _tempEndDate = date);
                    }
                  },
                  icon: const Icon(HugeIcons.strokeRoundedCalendar03, size: 16),
                  label: Text(
                    _tempEndDate != null
                        ? '${_tempEndDate!.day}/${_tempEndDate!.month}/${_tempEndDate!.year}'
                        : 'End Date',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (_tempStartDate != null || _tempEndDate != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _tempStartDate = null;
                  _tempEndDate = null;
                });
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear Dates'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupByTab(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group By',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Organize move history by different attributes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _buildGroupOption(
            'None',
            'Show all moves in a single list',
            null,
            Icons.list,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Status',
            'Group by move status',
            'state',
            Icons.flag_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Date',
            'Group by move date',
            'date',
            HugeIcons.strokeRoundedCalendar03,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Product',
            'Group by product name',
            'product',
            Icons.inventory_2_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Location',
            'Group by source/destination location',
            'location',
            Icons.location_on_outlined,
            isDark,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupOption(
    String title,
    String description,
    String? value,
    IconData icon,
    bool isDark,
    ThemeData theme,
  ) {
    final isSelected = _tempGroupBy == value;

    return InkWell(
      onTap: () {
        HapticsService.selection();
        setState(() => _tempGroupBy = value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primaryColor.withOpacity(0.2)
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.primaryColor
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.primaryColor
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }
}
