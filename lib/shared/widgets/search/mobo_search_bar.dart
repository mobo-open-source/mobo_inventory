import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';

class MoboSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool hasActiveFilter;

  const MoboSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onFilterTap,
    this.onChanged,
    this.readOnly = false,
    this.hasActiveFilter = false,
  });

  @override
  State<MoboSearchBar> createState() => _MoboSearchBarState();
}

class _MoboSearchBarState extends State<MoboSearchBar> {
  // §6 — the search field and its filter button share one height, radius
  // and soft search shadow.
  static const List<BoxShadow> _designShadow = AppShadows.search;

  static const double _height = 40;
  static const double _radius = AppRadius.md;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(MoboSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFilter = widget.onFilterTap != null;

    final surface = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF99A1AF);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF99A1AF);
    final filterIconColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Row(
      children: [
        Expanded(
          child: _buildSearchField(surface, textColor, hintColor, iconColor),
        ),
        if (hasFilter) ...[
          const SizedBox(width: 10),
          _buildFilterButton(surface, filterIconColor),
        ],
      ],
    );
  }

  Widget _buildSearchField(
    Color surface,
    Color textColor,
    Color hintColor,
    Color iconColor,
  ) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: _designShadow,
      ),
      child: TextField(
        controller: widget.controller,
        readOnly: widget.readOnly,
        onChanged: widget.onChanged,
        style: TextStyle(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: hintColor,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 20,
              color: iconColor,
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: iconColor,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                  },
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildFilterButton(Color surface, Color iconColor) {
    final isActive = widget.hasActiveFilter;
    return Container(
      width: _height,
      height: _height,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : surface,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: isActive ? [] : _designShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: widget.readOnly ? null : widget.onFilterTap,
          child: Center(
            child: SvgPicture.asset(
              'assets/images/new_filter.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                isActive ? Colors.white : iconColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
