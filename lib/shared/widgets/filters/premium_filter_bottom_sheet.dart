import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/const/app_colors.dart' as app_colors;
import '../../../core/theme/app_theme.dart';
import '../forms/mobo_date_picker.dart';
import '../layout/collapsible_header_layout.dart';

/// Represents a single filter option (checkbox, chip, dropdown, range, etc.)
class FilterOption {
  final String title;
  final String? subtitle;
  bool value;
  final String? type;
  final List<Map<String, dynamic>>? options;
  final Map<String, dynamic>? rangeData;
  dynamic selectedValue;

  FilterOption({
    required this.title,
    this.subtitle,
    required this.value,
    this.type = 'checkbox',
    this.options,
    this.rangeData,
    this.selectedValue,
  });
}

/// Logical grouping of related filter options (e.g. "Status", "Date", "Salesperson")
class FilterGroup {
  final String title;
  final List<FilterOption> options;
  bool isExpanded;

  FilterGroup({
    required this.title,
    required this.options,
    this.isExpanded = false,
  });
}

/// Advanced filter bottom sheet with tabs: Filters + Group By
class PremiumFilterBottomSheet extends StatefulWidget {
  final List<FilterGroup> filterGroups;
  final List<FilterGroup> groupByOptions;
  final Function(Map<String, dynamic>) onApply;
  final String title;
  final Color primaryColor;
  final bool clearAll;

  const PremiumFilterBottomSheet({
    super.key,
    required this.filterGroups,
    this.groupByOptions = const [],
    required this.onApply,
    this.clearAll = true,
    this.title = 'Filters',
    this.primaryColor = app_colors.primaryColor,
  });

  /// Convenience method to show the bottom sheet
  static void show({
    required BuildContext context,
    required List<FilterGroup> filterGroups,
    List<FilterGroup> groupByOptions = const [],
    required Function(Map<String, dynamic>) onApply,
    String title = 'Filters',
    Color primaryColor = app_colors.primaryColor,
  }) {
    showModalBottomSheet(
      isScrollControlled: true,
      useRootNavigator: true,
      // Keeps the sheet below the status bar when it grows to (nearly) full
      // height on a short screen; the portrait sheet never gets that tall.
      useSafeArea: true,
      // Centred and capped in landscape, so rows and the footer buttons
      // aren't stretched across the whole width.
      constraints: const BoxConstraints(maxWidth: _maxSheetWidth),
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return PremiumFilterBottomSheet(
          filterGroups: filterGroups,
          groupByOptions: groupByOptions,
          onApply: onApply,
          title: title,
          primaryColor: primaryColor,
        );
      },
    );
  }

  /// Widest the sheet gets (the Material 3 default for bottom sheets).
  static const double _maxSheetWidth = 640;

  @override
  State<PremiumFilterBottomSheet> createState() =>
      _PremiumFilterBottomSheetState();
}

class _PremiumFilterBottomSheetState extends State<PremiumFilterBottomSheet>
    with TickerProviderStateMixin {
  late List<FilterGroup> _tempFilterGroups;
  late List<FilterGroup> _tempGroupByOptions;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    _tempFilterGroups = widget.filterGroups.map((group) {
      return FilterGroup(
        title: group.title,
        isExpanded: group.isExpanded,
        options: group.options.map((option) {
          return FilterOption(
            title: option.title,
            subtitle: option.subtitle,
            value: option.value,
            type: option.type,
            options: option.options,
            rangeData: option.rangeData,
            selectedValue: option.selectedValue,
          );
        }).toList(),
      );
    }).toList();

    _tempGroupByOptions = widget.groupByOptions.map((group) {
      return FilterGroup(
        title: group.title,
        isExpanded: group.isExpanded,
        options: group.options.map((option) {
          return FilterOption(
            title: option.title,
            subtitle: option.subtitle,
            value: option.value,
            type: option.type,
            options: option.options,
            rangeData: option.rangeData,
            selectedValue: option.selectedValue,
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectValues() {
    Map<String, dynamic> result = {};

    for (var group in _tempFilterGroups) {
      String groupPrefix = '${group.title.toLowerCase().replaceAll(' ', '_')}_';
      for (var option in group.options) {
        String key = option.title.toLowerCase().replaceAll(' ', '_');
        result['$groupPrefix$key'] = option.value;
        if (option.selectedValue != null) {
          result['${groupPrefix}${key}_value'] = option.selectedValue;
        }
      }
    }

    for (var group in _tempGroupByOptions) {
      String groupPrefix = '${group.title.toLowerCase().replaceAll(' ', '_')}_';
      for (var option in group.options) {
        String key = option.title.toLowerCase().replaceAll(' ', '_');
        result['$groupPrefix$key'] = option.value;
        if (option.selectedValue != null) {
          result['${groupPrefix}${key}_value'] = option.selectedValue;
        }
      }
    }

    return result;
  }

  /// Gap left above the sheet on a short screen, so the barrier still shows
  /// and it reads as a sheet rather than a new page.
  static const double _compactTopGap = 8;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    );

    if (isCompactHeight(context)) {
      return _buildCompactSheet(isDark, decoration);
    }

    return _buildSurface(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDragHandle(isDark),
          _buildHeader(isDark),
          _buildTabBar(isDark),
          Expanded(child: _buildTabBarView(isDark)),
          _buildBottomActions(isDark),
        ],
      ),
    );
  }

  /// The sheet's rounded, coloured surface. The transparent [Material] gives
  /// the radio tiles, chips and date fields somewhere above that colour to
  /// paint their ripples; otherwise they land on the route's Material
  /// underneath it and never show.
  Widget _buildSurface({
    required double height,
    required BoxDecoration decoration,
    required Widget child,
  }) {
    return Container(
      height: height,
      decoration: decoration,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }

  /// Short-screen (phone in landscape) layout. At 80% of a ~400px height the
  /// fixed title, tabs and footer would leave the options a sliver, so here
  /// the sheet takes nearly all the height below the status bar, the title
  /// and tabs scroll away with the options, and only the drag handle and the
  /// footer buttons stay pinned.
  Widget _buildCompactSheet(bool isDark, BoxDecoration decoration) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return _buildSurface(
          height: available - _compactTopGap,
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDragHandle(isDark),
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(isDark, compact: true),
                          _buildTabBar(isDark),
                        ],
                      ),
                    ),
                  ],
                  // Each tab's scroll view has no controller of its own, so
                  // it picks up the NestedScrollView's and drives the header.
                  body: _buildTabBarView(isDark),
                ),
              ),
              _buildBottomActions(isDark, compact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarView(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [_buildFiltersTab(isDark), _buildGroupByTab(isDark)],
    );
  }

  Widget _buildHeader(bool isDark, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 4 : 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: widget.primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
        // TabBar applies these as-is, without the theme's font.
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(height: 48, text: 'Filter'),
          Tab(height: 48, text: 'Group By'),
        ],
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFiltersTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveSelections(isDark),
          ...List.generate(_tempFilterGroups.length, (groupIndex) {
            return _buildFilterGroup(groupIndex, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildActiveSelections(bool isDark) {
    List<Widget> activeChips = [];

    for (var group in _tempFilterGroups) {
      int count = 0;
      for (var option in group.options) {
        if (option.value == true) count++;
      }
      if (count > 0) {
        activeChips.add(
          _buildActiveChip(
            label: '${group.title} ($count)',
            isDark: isDark,
            onRemove: () {
              setState(() {
                for (var opt in group.options) {
                  opt.value = false;
                }
              });
            },
          ),
        );
      }
    }

    if (activeChips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.primaryColor,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(spacing: 8, runSpacing: 4, children: activeChips),
        ],
      ),
    );
  }

  Widget _buildActiveChip({
    required String label,
    required bool isDark,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: widget.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(int groupIndex, bool isDark) {
    final group = _tempFilterGroups[groupIndex];
    final isDateField = group.title.toLowerCase().contains('date');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
          child: Text(
            group.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        if (isDateField)
          _buildDateRangeGroup(group, isDark)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.asMap().entries.map((entry) {
              return _buildChipOption(groupIndex, entry.key, isDark);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDateRangeGroup(FilterGroup group, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: group.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < group.options.length - 1 ? 8 : 0,
            ),
            child: _buildDateInput(
              label: option.title,
              value: option.selectedValue,
              isDark: isDark,
              onTap: () async {
                final date = await MoboDatePicker.show(
                  context: context,
                  initialDate: option.selectedValue ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    option.selectedValue = date;
                    option.value = true;
                  });
                }
              },
              onClear: () {
                setState(() {
                  option.selectedValue = null;
                  option.value = false;
                });
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateInput({
    required String label,
    required dynamic value,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final displayValue = value is DateTime
        ? DateFormat('MMM dd, yyyy').format(value)
        : label;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        // §6 filled field — transparent border, no outline at rest.
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : AppTheme.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 16,
              color: isDark ? Colors.grey[500]! : Colors.grey[600]!,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayValue,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: value != null
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontSize: 13,
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                  fontStyle: value != null
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipOption(int groupIndex, int optionIndex, bool isDark) {
    final option = _tempFilterGroups[groupIndex].options[optionIndex];

    return _buildChoiceChip(
      label: option.title,
      selected: option.value,
      isDark: isDark,
      onSelected: (val) {
        setState(() {
          option.value = val;
        });
      },
    );
  }

  /// The sheet's selectable chip: a pale primary tint with a grey outline
  /// at rest, filled primary once selected.
  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required bool isDark,
    required ValueChanged<bool> onSelected,
    double fontSize = 13,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: selected,
      selectedColor: widget.primaryColor,
      backgroundColor: widget.primaryColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? widget.primaryColor
              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      onSelected: onSelected,
      showCheckmark: false,
    );
  }

  Widget _buildGroupByTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group by',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          _buildNoneGroupByOption(isDark),
          const SizedBox(height: 10),
          Divider(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 10),
          ...List.generate(_tempGroupByOptions.length, (groupIndex) {
            return _buildGroupByGroup(groupIndex, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildNoneGroupByOption(bool isDark) {
    bool isNoneSelected = true;
    for (var group in _tempGroupByOptions) {
      for (var option in group.options) {
        if (option.value == true) {
          isNoneSelected = false;
          break;
        }
      }
    }

    return RadioListTile<bool>(
      title: Text(
        'None',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Display as a simple list',
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      value: true,
      groupValue: isNoneSelected,
      onChanged: (value) {
        setState(() {
          for (var group in _tempGroupByOptions) {
            for (var option in group.options) {
              option.value = false;
            }
          }
        });
      },
      activeColor: widget.primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildGroupByGroup(int groupIndex, bool isDark) {
    final group = _tempGroupByOptions[groupIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.title.isNotEmpty && group.title != 'Group By')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              group.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ...group.options.asMap().entries.map((entry) {
          final option = entry.value;
          final isDateField =
              option.title.toLowerCase().contains('date') ||
              option.title.toLowerCase().contains('deadline') ||
              option.title.toLowerCase().contains('last stage');

          return Column(
            children: [
              RadioListTile<String>(
                title: Text(
                  option.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  option.subtitle ?? 'Group by ${option.title.toLowerCase()}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                value: option.title,
                groupValue: _getSelectedGroupByTitle(),
                onChanged: (value) {
                  setState(() {
                    for (var g in _tempGroupByOptions) {
                      for (var opt in g.options) {
                        opt.value = opt.title == value;
                        if (opt.value && isDateField) {
                          opt.selectedValue ??= 'day';
                        }
                      }
                    }
                  });
                },
                activeColor: widget.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
              if (option.value && isDateField)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Year', 'Quarter', 'Month', 'Week', 'Day'].map((
                      unit,
                    ) {
                      final selected =
                          option.selectedValue == unit.toLowerCase();
                      return _buildChoiceChip(
                        label: unit,
                        selected: selected,
                        isDark: isDark,
                        fontSize: 12,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              option.selectedValue = unit.toLowerCase();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  String? _getSelectedGroupByTitle() {
    for (var group in _tempGroupByOptions) {
      for (var option in group.options) {
        if (option.value) return option.title;
      }
    }
    return null;
  }

  Widget _buildBottomActions(bool isDark, {bool compact = false}) {
    final vertical = compact ? 12.0 : 20.0;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: vertical + MediaQuery.of(context).padding.bottom,
        top: vertical,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  for (var group in _tempFilterGroups) {
                    for (var opt in group.options) {
                      opt.value = false;
                      opt.selectedValue = null;
                    }
                  }
                  for (var group in _tempGroupByOptions) {
                    for (var opt in group.options) {
                      opt.value = false;
                      opt.selectedValue = null;
                    }
                  }
                  widget.onApply(_collectValues());
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: widget.primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: widget.primaryColor,
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_collectValues());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
