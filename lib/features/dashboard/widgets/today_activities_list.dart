import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../models/today_activity.dart';
import 'dashboard_empty_card.dart';

class TodayActivitiesList extends StatelessWidget {
  final List<TodayActivity> items;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  const TodayActivitiesList({
    super.key,
    required this.items,
    this.isLoading = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Today's Activities / To-Dos",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (onSeeAll != null)
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading && items.isEmpty)
          _shimmerList(context)
        else if (items.isEmpty)
          const DashboardEmptyCard(
            icon: Icons.checklist_rounded,
            title: 'No activities today',
            subtitle: 'Your recent activities will appear here',
          )
        else
          // Stacked and full width, like the other sections: a row of fixed
          // 260px tiles left a lone activity as a short card.
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _tile(context, items[i]),
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, TodayActivity a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(isDark),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.checklist_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.displayTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(a),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _deadline(a),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(TodayActivity a) {
    final model = a.resModel.replaceAll('.', ' ');
    return '$model #${a.resId}';
  }

  String _deadline(TodayActivity a) {
    final d = a.deadline;
    if (d == null) return '';

    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  Widget _shimmerList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Column(
        children: List.generate(4, (i) => i)
            .map(
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 74,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
