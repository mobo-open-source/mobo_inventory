import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';

/// A single icon action rendered inside the trailing card of [MoboSearchFilterBar]
/// (e.g. voice search, barcode scan). The filter icon is always first and is
/// managed internally via [MoboSearchFilterBar.onFilterTap]/[MoboSearchFilterBar.hasActiveFilter].
class SearchBarAction {
  final Widget icon;
  final VoidCallback? onTap;
  final String tooltip;

  const SearchBarAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
}

/// Common search bar + filter card widget used across list screens.
///
/// Renders a search [TextField] on the left and, when [onFilterTap] is set,
/// a single trailing card containing the filter icon plus any [extraActions]
/// (e.g. voice search, barcode scan) separated by thin dividers.
class MoboSearchFilterBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;
  final List<SearchBarAction> extraActions;
  final bool readOnly;

  const MoboSearchFilterBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.extraActions = const [],
    this.readOnly = false,
  });

  @override
  State<MoboSearchFilterBar> createState() => _MoboSearchFilterBarState();
}

class _MoboSearchFilterBarState extends State<MoboSearchFilterBar> {
  // §6 — the search field and its action buttons share one height, radius
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
  void didUpdateWidget(MoboSearchFilterBar oldWidget) {
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
    final hasCard = widget.onFilterTap != null || widget.extraActions.isNotEmpty;

    final surface = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF99A1AF);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF99A1AF);

    return Row(
      children: [
        Expanded(
          child: _buildSearchField(surface, textColor, hintColor, iconColor),
        ),
        if (hasCard) ...[
          const SizedBox(width: 10),
          _buildActionsCard(isDark, surface),
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
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
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

  Widget _buildActionsCard(bool isDark, Color surface) {
    final iconColor = isDark ? Colors.white : Colors.black;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final children = <Widget>[];

    if (widget.onFilterTap != null) {
      children.add(
        _buildActionIcon(
          onTap: widget.readOnly ? null : widget.onFilterTap,
          tooltip: 'Filter & Group By',
          child: SvgPicture.asset(
            'assets/images/new_filter.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      );
    }

    for (final action in widget.extraActions) {
      if (children.isNotEmpty) {
        children.add(Container(width: 1, height: 24, color: dividerColor));
      }
      children.add(
        _buildActionIcon(
          onTap: action.onTap,
          tooltip: action.tooltip,
          child: action.icon,
        ),
      );
    }

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: _designShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildActionIcon({
    required VoidCallback? onTap,
    required String tooltip,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _height,
            height: _height,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
