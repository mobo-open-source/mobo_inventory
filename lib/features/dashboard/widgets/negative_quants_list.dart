import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../models/negative_quant.dart';
import 'dashboard_empty_card.dart';

class NegativeQuantsList extends StatelessWidget {
  final List<NegativeQuant> items;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  const NegativeQuantsList({
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
              'Negative Stock Alerts',
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
            icon: Icons.check_circle_outline_rounded,
            title: 'No negative stock found',
            subtitle: 'Every stock quantity is zero or above',
          )
        else
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

  Widget _tile(BuildContext context, NegativeQuant q) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = StatusColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(isDark),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.productName.isNotEmpty ? q.productName : '—',
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
                  q.locationName,
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
            // Fractional quantities (kg, m…) keep their decimals.
            q.quantity == q.quantity.roundToDouble()
                ? q.quantity.toStringAsFixed(0)
                : q.quantity.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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
