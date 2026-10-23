import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/last_opened_provider.dart';
import '../../../core/theme/app_theme.dart';

class RecentItemsWidget extends StatelessWidget {
  final List<LastOpenedItem> recentItems;
  final bool isLoading;
  final bool isDark;
  final Function(LastOpenedItem) onItemTap;

  const RecentItemsWidget({
    super.key,
    required this.recentItems,
    required this.isLoading,
    required this.isDark,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Working On',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          _buildLoadingState()
        else if (recentItems.isEmpty)
          _buildEmptyState()
        else
          _buildRecentItemsList(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          constraints: const BoxConstraints(minHeight: 80),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(isDark),
          child: _buildRecentItemShimmer(),
        ),
      ),
    );
  }

  Widget _buildRecentItemShimmer() {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 11,
            width: 50,
            decoration: BoxDecoration(
              color: shimmerBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(isDark),
      child: Center(
        child: Column(
          children: [
            Icon(
              HugeIcons.strokeRoundedClock01,
              size: 32,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No recent items',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your recently viewed items will appear here',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemsList() {
    return Column(
      children: recentItems
          .take(5)
          .map(
            (item) => Container(
              constraints: const BoxConstraints(minHeight: 80),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppTheme.cardDecoration(isDark),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onItemTap(item),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _buildRecentItem(item),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentItem(LastOpenedItem item) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _getTypeColor(item.type).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            LastOpenedItem.iconFromKey(item.iconKey),
            color: _getTypeColor(item.type),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'product':
        return AppTheme.primaryColor;
      case 'transfer':
        return StatusColors.blue;
      case 'replenishment':
        return StatusColors.orange;
      default:
        return StatusColors.grey;
    }
  }
}
