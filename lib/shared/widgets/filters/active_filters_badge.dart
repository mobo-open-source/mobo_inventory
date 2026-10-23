import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// "N Active" pill on the filter bar above a list/kanban view: solid black
/// with white text, matching the group-by pill that often sits beside it.
class ActiveFiltersBadge extends StatelessWidget {
  final int count;
  final ThemeData theme;
  final bool hasGroupBy;

  const ActiveFiltersBadge({
    super.key,
    required this.count,
    required this.theme,
    this.hasGroupBy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    if (count == 0) {
      if (hasGroupBy) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No filters applied',
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? Colors.white70
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // Keeps the black pill visible against the dark scaffold.
        border: isDark ? Border.all(color: Colors.grey[700]!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Active',
            style: TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
