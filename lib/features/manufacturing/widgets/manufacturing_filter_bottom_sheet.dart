import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/filters/filter_chip_widget.dart';
import '../providers/manufacturing_provider.dart';

class ManufacturingFilterBottomSheet extends StatefulWidget {
  final ManufacturingProvider provider;
  final VoidCallback? onClearSearch;

  const ManufacturingFilterBottomSheet({
    super.key,
    required this.provider,
    this.onClearSearch,
  });

  @override
  State<ManufacturingFilterBottomSheet> createState() =>
      _ManufacturingFilterBottomSheetState();
}

class _ManufacturingFilterBottomSheetState
    extends State<ManufacturingFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _allStates = const [
    'draft',
    'confirmed',
    'planned',
    'progress',
    'to_close',
    'done',
    'cancel',
  ];

  late List<String> _selectedStates;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _groupBy;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;

    _selectedStates = List.from(p.states);
    _startDate = p.startDate;
    _endDate = p.endDate;
    _groupBy = p.selectedGroupBy;

    final initialIndex = _groupBy != null ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
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

            _buildFooter(theme, isDark),
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
            children: _allStates.map((s) {
              final selected = _selectedStates.contains(s);
              return FilterChipWidget(
                label: _stateLabel(s),
                isSelected: selected,
                onSelected: (val) {
                  setState(() {
                    val ? _selectedStates.add(s) : _selectedStates.remove(s);
                  });
                },
              );
            }).toList(),
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
                  icon: const Icon(HugeIcons.strokeRoundedCalendar03, size: 16),
                  label: Text(_formatDate(_startDate) ?? 'Start Date'),
                  onPressed: () => _pickDate(context, true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                  icon: const Icon(HugeIcons.strokeRoundedCalendar03, size: 16),
                  label: Text(_formatDate(_endDate) ?? 'End Date'),
                  onPressed: () => _pickDate(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
          if (_startDate != null || _endDate != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  setState(() => {_startDate = null, _endDate = null}),
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
            'Organize manufacturing orders by different attributes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _groupOption(
            'None',
            'Show all in a single list',
            null,
            Icons.list,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _groupOption(
            'Status',
            'Group by manufacturing status',
            'state',
            Icons.flag_outlined,
            isDark,
            theme,
          ),
          const SizedBox(height: 12),
          _groupOption(
            'Date',
            'Group by created date',
            'create_date',
            HugeIcons.strokeRoundedCalendar03,
            isDark,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _groupOption(
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
              onPressed: _clearAll,
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
              onPressed: _apply,
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

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        isStart ? _startDate = picked : _endDate = picked;
      });
    }
  }

  String? _formatDate(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  void _clearAll() async {

    setState(() {
      _selectedStates.clear();
      _startDate = null;
      _endDate = null;
      _groupBy = null;
    });

    widget.onClearSearch?.call();

    if (mounted) Navigator.pop(context);

    Future.microtask(() async {
      widget.provider.clearFilters();
      await widget.provider.fetchProductions(forceRefresh: true);
    });
  }

  void _apply() async {
    if (mounted) Navigator.pop(context);
    widget.provider.setGroupBy(_groupBy);
    widget.provider.fetchProductions(
      states: _selectedStates,
      startDate: _startDate,
      endDate: _endDate,
      forceRefresh: true,
    );
    if (_groupBy != null) {
      widget.provider.fetchGroupSummary();
    }
  }

  String _stateLabel(String s) {
    switch (s) {
      case 'draft':
        return 'Draft';
      case 'confirmed':
        return 'Confirmed';
      case 'planned':
        return 'Planned';
      case 'progress':
        return 'In Progress';
      case 'to_close':
        return 'To Close';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return s;
    }
  }
}
