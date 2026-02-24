import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import '../models/today_activity.dart';

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
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading && items.isEmpty)
          _shimmerList(context)
        else if (items.isEmpty)
          _emptyState(context, isDark, 'No activities today')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              if (isWide) {
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _tile(context, items[i]),
                );
              }

              return SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  padding: EdgeInsets.zero,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) => SizedBox(width: 260, child: _tile(context, items[i])),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, bool isDark , String errtext) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 120,
            child: Lottie.network(
              'https://assets9.lottiefiles.com/packages/lf20_t24tpvcu.json',
              repeat: true,
              animate: true,
              errorBuilder: (context, error, stack) => Icon(
                HugeIcons.strokeRoundedCalendar03,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errtext,

            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, TodayActivity a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.checklist_rounded, color: color, size: 18),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(a),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _deadline(a),
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
    return Column(
      children: List.generate(4, (i) => i)
          .map((_) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
              ))
          .toList(),
    );
  }
}
