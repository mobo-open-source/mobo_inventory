import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DashboardStatsShimmer extends StatelessWidget {
  const DashboardStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.15,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            highlightColor: (isDark ? Colors.grey[700]! : Colors.grey[200]!),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 70,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 40,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
