import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';

/// §7 segmented view selector: list vs kanban, the active segment filled.
///
/// The segments are keyed `${keyPrefix}ViewToggleList` and
/// `${keyPrefix}ViewToggleKanban`.
class ViewModeToggle extends StatelessWidget {
  final bool isKanban;
  final bool isDark;
  final ValueChanged<bool> onChanged;
  final String keyPrefix;

  const ViewModeToggle({
    super.key,
    required this.isKanban,
    required this.isDark,
    required this.onChanged,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 35),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(AppRadius.segment),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            key: ValueKey('${keyPrefix}ViewToggleList'),
            icon: HugeIcons.strokeRoundedLeftToRightListBullet,
            tooltip: 'List view',
            selected: !isKanban,
            onTap: () => onChanged(false),
          ),
          _segment(
            key: ValueKey('${keyPrefix}ViewToggleKanban'),
            icon: HugeIcons.strokeRoundedGridView,
            tooltip: 'Kanban view',
            selected: isKanban,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required Key key,
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedFg = isDark ? Colors.black : Colors.white;
    final idleFg = isDark ? Colors.grey[400]! : Colors.grey[700]!;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(icon, size: 18, color: selected ? selectedFg : idleFg),
          ),
        ),
      ),
    );
  }
}
