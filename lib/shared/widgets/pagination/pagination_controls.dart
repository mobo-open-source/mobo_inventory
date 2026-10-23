import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A standard UI component for navigating through paginated data sets.
class PaginationControls extends StatelessWidget {
  final bool canGoToPreviousPage;
  final bool canGoToNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final String paginationText;
  final bool isDark;
  final ThemeData theme;

  /// When true, an arrow is omitted entirely instead of shown greyed out once
  /// there is no page to move to in that direction. Each arrow is judged on its
  /// own, so the page you can still reach stays reachable.
  final bool hideDisabledArrows;

  const PaginationControls({
    super.key,
    required this.canGoToPreviousPage,
    required this.canGoToNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.paginationText,
    required this.isDark,
    required this.theme,
    this.hideDisabledArrows = true,
  });

  /// The pager of a grouped list, as Odoo shows it: a grouped list pages
  /// through its groups, not its records, so it reads `1-4/4` for four
  /// groups — each group's header carries its own record count. (A grouped
  /// kanban has no pager at all.)
  static String groupsText(int groupCount) => '1-$groupCount/$groupCount';

  @override
  Widget build(BuildContext context) {
    // A single page (the usual case once a filter narrows the list) still
    // shows its record count; only the arrows, which have nowhere to go, are
    // left out.
    final hasOtherPages = canGoToPreviousPage || canGoToNextPage;

    final activeColor = isDark ? Colors.white : Colors.black87;
    final dimColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Text(
            paginationText,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
        if (hasOtherPages) ...[
          _buildArrow(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            enabled: canGoToPreviousPage,
            onTap: onPreviousPage,
            activeColor: activeColor,
            dimColor: dimColor,
          ),
          _buildArrow(
            icon: HugeIcons.strokeRoundedArrowRight01,
            enabled: canGoToNextPage,
            onTap: onNextPage,
            activeColor: activeColor,
            dimColor: dimColor,
          ),
        ],
      ],
    );
  }

  Widget _buildArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required Color activeColor,
    required Color dimColor,
  }) {
    return SizedBox(
      width: 32,
      height: 36,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Center(
          child: HugeIcon(
            icon: icon,
            size: 20,
            color: enabled ? activeColor : dimColor,
          ),
        ),
      ),
    );
  }
}
