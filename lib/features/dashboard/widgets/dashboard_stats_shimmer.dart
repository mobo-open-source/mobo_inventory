import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_stat_card.dart';

class DashboardStatsShimmer extends StatelessWidget {
  const DashboardStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          // Same grid as the loaded cards, so nothing jumps when they arrive.
          gridDelegate: DashboardStatCard.gridDelegate(
            context,
            constraints.maxWidth,
            itemCount: 6,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              decoration: AppTheme.cardDecoration(isDark),
              padding: const EdgeInsets.all(14),
              child: Shimmer.fromColors(
                baseColor: shimmerBase,
                highlightColor: (isDark ? Colors.grey[700]! : Colors.grey[50]!),
                // Same arrangement as the loaded card: count and icon on one
                // row, the title and subtitle beneath.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 24,
                          decoration: BoxDecoration(
                            color: shimmerBase,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: DashboardStatCard.iconBoxSize(context),
                          height: DashboardStatCard.iconBoxSize(context),
                          decoration: BoxDecoration(
                            color: shimmerBase,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 90,
                      height: 14,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
