import 'package:flutter/material.dart';
import '../../../../shared/widgets/filters/filter_chip_widget.dart';
import '../providers/replenishment_provider.dart';

class ReplenishmentFilterBottomSheet extends StatefulWidget {
  final ReplenishmentProvider provider;
  final VoidCallback? onClearSearch;
  const ReplenishmentFilterBottomSheet({
    super.key,
    required this.provider,
    this.onClearSearch,
  });

  @override
  State<ReplenishmentFilterBottomSheet> createState() =>
      _ReplenishmentFilterBottomSheetState();
}

class _ReplenishmentFilterBottomSheetState
    extends State<ReplenishmentFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late bool _notSnoozed;
  late String _trigger;
  String? _groupBy;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;

    final initialIndex = p.selectedGroupBy != null ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );

    _notSnoozed = p.notSnoozed;
    _trigger = p.trigger;
    _groupBy = p.selectedGroupBy;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

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
            _buildFooter(theme, isDark),
          ],
        ),
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
    final isSelected = _groupBy == value;

    return InkWell(
      onTap: () => setState(() => _groupBy = value),
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

  Widget _buildFilterTab(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
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
                label: 'Not Snoozed',
                isSelected: _notSnoozed,
                onSelected: (v) => setState(() => _notSnoozed = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Trigger',
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
                isSelected: _trigger.isEmpty,
                onSelected: (_) => setState(() => _trigger = ''),
              ),
              FilterChipWidget(
                label: 'Manual',
                isSelected: _trigger == 'manual',
                onSelected: (_) => setState(() => _trigger = 'manual'),
              ),
              FilterChipWidget(
                label: 'Auto',
                isSelected: _trigger == 'auto',
                onSelected: (_) => setState(() => _trigger = 'auto'),
              ),
            ],
          ),
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
            'Organize replenishment rules by different attributes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          _buildGroupOption(
            'None',
            'Show all rules in a single list',
            null,
            Icons.list,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),

          _buildGroupOption(
            'Product',
            'Group by product',
            'product_id',
            Icons.inventory_2_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),

          _buildGroupOption(
            'Location',
            'Group by stock location',
            'location_id',
            Icons.place_outlined,
            isDark,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    return Container(
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

                setState(() {
                  _notSnoozed = true;
                  _trigger = 'manual';
                  _groupBy = null;
                });

                widget.onClearSearch?.call();

                if (mounted) Navigator.pop(context);

                Future.microtask(() async {
                  widget.provider.clearFilters();
                  await widget.provider.fetch(forceRefresh: true);
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
              onPressed: () {
                widget.provider.applyFilters(
                  notSnoozed: _notSnoozed,
                  trigger: _trigger,
                  groupBy: _groupBy,
                );
                Navigator.pop(context);
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
    );
  }
}
