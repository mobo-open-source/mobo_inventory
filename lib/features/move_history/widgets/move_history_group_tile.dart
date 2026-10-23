import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/move_history_item.dart';
import 'move_history_list_tile.dart';
import '../../../core/routing/app_routes.dart';

class MoveHistoryGroupTile extends StatelessWidget {
  final String groupKey;

  /// The group's move lines on the server, not just those loaded.
  final int count;

  /// The group's loaded move lines; null while they load.
  final List<MoveHistoryItem>? items;
  final bool isDark;
  final ThemeData theme;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// Shown under the move lines, e.g. "Load more".
  final Widget? footer;

  const MoveHistoryGroupTile({
    super.key,
    required this.groupKey,
    required this.count,
    required this.items,
    required this.isDark,
    required this.theme,
    required this.isExpanded,
    required this.onToggle,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history,
                        color: theme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupKey,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count ${count == 1 ? 'move' : 'moves'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (items == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: theme.primaryColor),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  children: [
                    for (final item in items!)
                      GestureDetector(
                        onTap: () {
                          context.pushNamed(
                            AppRoutes.moveHistoryDetail,
                            extra: item,
                          );
                        },
                        child: MoveHistoryListTile(item: item, isDark: isDark),
                      ),
                    if (footer != null) footer!,
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
