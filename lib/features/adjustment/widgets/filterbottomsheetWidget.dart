import 'package:flutter/material.dart';
import '../../../../shared/widgets/filters/filter_chip_widget.dart';
import '../providers/adjustment_provider.dart';

/// A bottom sheet widget for filtering and grouping inventory adjustments.
class FilterBottomSheet extends StatefulWidget {
  final AdjustmentProvider provider;

  const FilterBottomSheet({super.key, required this.provider});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet>
    with SingleTickerProviderStateMixin {
  String? _tempGroupBy;
  late TabController _tabController;

  bool _tempInternalLocations = true;
  bool _tempTransitLocations = true;
  bool _tempOnHand = false;
  bool _tempToCount = false;
  bool _tempToApply = false;
  bool _tempInStock = false;
  bool _tempConflicts = false;
  bool _tempNegativeStock = false;
  DateTime? _tempIncomingStart;
  DateTime? _tempIncomingEnd;

  bool _tempOnHandFlag = false;
  bool _tempQuantityPositive = false;
  bool _tempCountedSet = false;
  bool _tempReservedOnly = false;
  bool _tempMineOnly = false;
  bool _tempIncomingToToday = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tempGroupBy = widget.provider.selectedGroupBy;
    _tempInternalLocations = widget.provider.filterInternalLocations;
    _tempTransitLocations = widget.provider.filterTransitLocations;
    _tempOnHand = widget.provider.filterOnHand;
    _tempToCount = widget.provider.filterToCount;
    _tempToApply = widget.provider.filterToApply;
    _tempInStock = widget.provider.filterInStock;
    _tempConflicts = widget.provider.filterConflicts;
    _tempNegativeStock = widget.provider.filterNegativeStock;
    _tempIncomingStart = widget.provider.incomingDateStart;
    _tempIncomingEnd = widget.provider.incomingDateEnd;

    _tempOnHandFlag = widget.provider.onHandFlag;
    _tempQuantityPositive = widget.provider.quantityPositive;
    _tempCountedSet = widget.provider.countedSet;
    _tempReservedOnly = widget.provider.reservedOnly;
    _tempMineOnly = widget.provider.mineOnly;
    _tempIncomingToToday = widget.provider.incomingDateToToday;
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
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black54,
                    ),
                    splashRadius: 20,
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
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
                        if (mounted) Navigator.pop(context);

                        Future.microtask(() async {
                          widget.provider.clearFilters();
                          widget.provider.setGroupBy(null);
                          await widget.provider.fetchAdjustments();
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
                        if (mounted) Navigator.pop(context);

                        final bool finalInternal =
                            _tempInternalLocations ||
                            (!_tempInternalLocations && !_tempTransitLocations);
                        final bool finalTransit =
                            _tempTransitLocations ||
                            (!_tempInternalLocations && !_tempTransitLocations);

                        widget.provider.fetchAdjustments(
                          searchQuery: widget.provider.searchQuery,
                          locationId: null,
                          internalLocations: finalInternal,
                          transitLocations: finalTransit,
                          onHand: _tempOnHand,
                          onHandFlag: _tempOnHandFlag,
                          quantityPositive: _tempQuantityPositive,
                          toCount: _tempToCount,
                          countedSet: _tempCountedSet,
                          toApply: _tempToApply,
                          inStock: _tempInStock,
                          conflicts: _tempConflicts,
                          negativeStock: _tempNegativeStock,
                          reservedOnly: _tempReservedOnly,
                          mineOnly: _tempMineOnly,
                          incomingDateStart: _tempIncomingStart,
                          incomingDateEnd: _tempIncomingEnd,
                          incomingDateToToday: _tempIncomingToToday,
                          updateFilters: true,
                        );

                        widget.provider.setGroupBy(_tempGroupBy);
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
            'Location Usage',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              FilterChipWidget(
                label: 'Internal',
                isSelected: _tempInternalLocations,
                onSelected: (selected) =>
                    setState(() => _tempInternalLocations = selected),
              ),
              FilterChipWidget(
                label: 'Transit',
                isSelected: _tempTransitLocations,
                onSelected: (selected) =>
                    setState(() => _tempTransitLocations = selected),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Stock Status',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              FilterChipWidget(
                label: 'All',
                isSelected:
                    !_tempOnHandFlag && !_tempQuantityPositive && !_tempInStock,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _tempOnHandFlag = false;
                      _tempQuantityPositive = false;
                      _tempInStock = false;
                    });
                  }
                },
              ),
              FilterChipWidget(
                label: 'On Hand',
                isSelected: _tempOnHandFlag,
                onSelected: (selected) =>
                    setState(() => _tempOnHandFlag = selected),
              ),
              FilterChipWidget(
                label: 'In Stock',
                isSelected: _tempInStock,
                onSelected: (selected) =>
                    setState(() => _tempInStock = selected),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Adjustment Status',
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
                label: 'To Count',
                isSelected: _tempToCount,
                onSelected: (selected) =>
                    setState(() => _tempToCount = selected),
              ),
              FilterChipWidget(
                label: 'To Apply',
                isSelected: _tempToApply,
                onSelected: (selected) =>
                    setState(() => _tempToApply = selected),
              ),
              FilterChipWidget(
                label: 'Counted Set',
                isSelected: _tempCountedSet,
                onSelected: (selected) =>
                    setState(() => _tempCountedSet = selected),
              ),
              FilterChipWidget(
                label: 'Conflicts',
                isSelected: _tempConflicts,
                onSelected: (selected) =>
                    setState(() => _tempConflicts = selected),
              ),
              FilterChipWidget(
                label: 'Negative Stock',
                isSelected: _tempNegativeStock,
                onSelected: (selected) =>
                    setState(() => _tempNegativeStock = selected),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Personal Filters',
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
                label: 'Reserved Only',
                isSelected: _tempReservedOnly,
                onSelected: (selected) =>
                    setState(() => _tempReservedOnly = selected),
              ),
              FilterChipWidget(
                label: 'Mine Only',
                isSelected: _tempMineOnly,
                onSelected: (selected) =>
                    setState(() => _tempMineOnly = selected),
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
            'Organize adjustments by different attributes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _buildGroupOption(
            'None',
            'Show all adjustments in a single list',
            null,
            Icons.list,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Location',
            'Group by inventory locations',
            'location_id',
            Icons.location_on_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Product',
            'Group by product names',
            'product_id',
            Icons.inventory_2_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Category',
            'Group by product categories',
            'product_categ_id',
            Icons.category_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Company',
            'Group by company',
            'company_id',
            Icons.business_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _buildGroupOption(
            'Lot/Serial',
            'Group by lot or serial numbers',
            'lot_id',
            Icons.qr_code_outlined,
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
      onTap: () => setState(() => _tempGroupBy = value),
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
