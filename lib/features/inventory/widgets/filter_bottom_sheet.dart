import 'package:flutter/material.dart';
import '../../../../shared/widgets/filters/filter_chip_widget.dart';
import '../providers/inventory_product_provider.dart';

/// A bottom sheet widget for filtering and grouping inventory products.
class FilterBottomSheet extends StatefulWidget {
  final InventoryProductProvider provider;
  final VoidCallback? onClearSearch;
  const FilterBottomSheet({
    super.key,
    required this.provider,
    this.onClearSearch,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late List<String> _tempCategories;
  late bool? _tempInStock;
  late String? _tempGroupBy;
  late TabController _tabController;

  String? _tempProductType;
  bool _tempSaleOk = false;
  bool _tempPurchaseOk = false;
  bool _tempAvailableInPos = false;
  bool _tempIsActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tempCategories = List.from(widget.provider.selectedCategories);
    _tempInStock = widget.provider.inStockOnly;
    _tempGroupBy = widget.provider.selectedGroupBy;
    _tempProductType = widget.provider.productType;
    _tempSaleOk = widget.provider.saleOk ?? false;
    _tempPurchaseOk = widget.provider.purchaseOk ?? false;
    _tempAvailableInPos = widget.provider.availableInPos ?? false;
    _tempIsActive = widget.provider.isActive ?? true;
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
            padding: const EdgeInsets.all(4),
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
                      widget.onClearSearch?.call();

                      if (mounted) Navigator.pop(context);

                      Future.microtask(() async {
                        widget.provider.clearFilters();
                        await widget.provider.fetchProducts(forceRefresh: true);
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
                      widget.provider.setGroupBy(_tempGroupBy);

                      if (mounted) {
                        Navigator.pop(context);
                      }

                      if (_tempGroupBy != null) {
                        widget.provider.fetchProducts(
                          categories: _tempCategories,
                          inStockOnly: _tempInStock,
                          productType: _tempProductType,
                          saleOk: _tempSaleOk ? true : null,
                          purchaseOk: _tempPurchaseOk ? true : null,
                          availableInPos: _tempAvailableInPos ? true : null,
                          isActive: _tempIsActive ? null : false,
                        );
                        widget.provider.fetchGroupSummary();
                      } else {
                        widget.provider.fetchProducts(
                          categories: _tempCategories,
                          inStockOnly: _tempInStock,
                          productType: _tempProductType,
                          saleOk: _tempSaleOk ? true : null,
                          purchaseOk: _tempPurchaseOk ? true : null,
                          availableInPos: _tempAvailableInPos ? true : null,
                          isActive: _tempIsActive ? null : false,
                        );
                      }
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
    );
  }

  Widget _buildFilterTab(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.provider.categories.isEmpty)
            Text(
              'Loading categories...',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ...widget.provider.categories.map((cat) {
                  final isSelected = _tempCategories.contains(cat);
                  return FilterChipWidget(
                    label: cat,
                    isSelected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tempCategories.add(cat);
                        } else {
                          _tempCategories.remove(cat);
                        }
                      });
                    },
                  );
                }),
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
            runSpacing: 12,
            children: [
              FilterChipWidget(
                label: 'All',
                isSelected: _tempInStock == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _tempInStock = null);
                  }
                },
              ),
              FilterChipWidget(
                label: 'In Stock',
                isSelected: _tempInStock == true,
                onSelected: (selected) {
                  setState(() => _tempInStock = selected ? true : null);
                },
              ),
              FilterChipWidget(
                label: 'Out of Stock',
                isSelected: _tempInStock == false,
                onSelected: (selected) {
                  setState(() => _tempInStock = selected ? false : null);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'Product Type',
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
                isSelected: _tempProductType == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _tempProductType = null);
                  }
                },
              ),
              FilterChipWidget(
                label: 'Storable',
                isSelected: _tempProductType == 'product',
                onSelected: (selected) => setState(
                  () => _tempProductType = selected ? 'product' : null,
                ),
              ),
              FilterChipWidget(
                label: 'Consumable',
                isSelected: _tempProductType == 'consu',
                onSelected: (selected) => setState(
                  () => _tempProductType = selected ? 'consu' : null,
                ),
              ),
              FilterChipWidget(
                label: 'Service',
                isSelected: _tempProductType == 'service',
                onSelected: (selected) => setState(
                  () => _tempProductType = selected ? 'service' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'Product Attributes',
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
                label: 'Can be Sold',
                isSelected: _tempSaleOk,
                onSelected: (selected) =>
                    setState(() => _tempSaleOk = selected),
              ),
              FilterChipWidget(
                label: 'Can be Purchased',
                isSelected: _tempPurchaseOk,
                onSelected: (selected) =>
                    setState(() => _tempPurchaseOk = selected),
              ),
              FilterChipWidget(
                label: 'Available in POS',
                isSelected: _tempAvailableInPos,
                onSelected: (selected) =>
                    setState(() => _tempAvailableInPos = selected),
              ),
              FilterChipWidget(
                label: 'Archived',
                isSelected: !_tempIsActive,
                onSelected: (selected) =>
                    setState(() => _tempIsActive = !selected),
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
            'Organize products by different attributes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.provider.groupByOptions.isEmpty) ...[
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading group options...',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildGroupOption(
              'None',
              'Show all products in a single list',
              null,
              Icons.list,
              isDark,
              theme,
            ),
            const SizedBox(height: 12),
            ...widget.provider.groupByOptions.entries.map((entry) {
              String description = '';
              IconData icon = Icons.category;

              switch (entry.key) {
                case 'type':
                  description = 'Group by Storable, Consumable, Service';
                  icon = Icons.inventory_2_outlined;
                  break;
                case 'categ_id':
                  description = 'Group by product categories';
                  icon = Icons.category_outlined;
                  break;
                case 'pos_categ_ids':
                  description = 'Group by POS categories';
                  icon = Icons.point_of_sale_outlined;
                  break;
                default:
                  description = 'Group by ${entry.value}';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildGroupOption(
                  entry.value,
                  description,
                  entry.key,
                  icon,
                  isDark,
                  theme,
                ),
              );
            }),
          ],
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
