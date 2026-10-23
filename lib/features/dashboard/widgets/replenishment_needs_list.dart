import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../models/replenishment_need.dart';
import 'dashboard_empty_card.dart';

class ReplenishmentNeedsList extends StatelessWidget {
  final List<ReplenishmentNeed> items;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  const ReplenishmentNeedsList({
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
              'Products Needing Replenishment',
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
            title: 'Nothing to replenish',
            subtitle: 'All products are above minimum stock',
          )
        else
          // Stacked rather than a horizontal strip, so each card has the
          // full width for the product's complete name.
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

  /// Whole quantities without decimals, fractional ones (kg, m…) with two.
  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _tile(BuildContext context, ReplenishmentNeed n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.productName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                if (n.locationName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _stockLevelBar(context, n),
              ],
            ),
          ),
          const SizedBox(width: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Filled brand circle; longer quantities scale down to fit.
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _qty(n.toOrder),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'To Order',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockLevelBar(BuildContext context, ReplenishmentNeed n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double target = n.maxQty > 0
        ? n.maxQty
        : (n.minQty > 0 ? n.minQty : 1);
    // Odoo reorders on the forecast, so that is what the bar shows.
    final double pct = (n.forecast / target).clamp(0.0, 1.0);
    final Color barColor = n.forecast < n.minQty
        ? AppTheme.primaryColor
        : (pct < 0.5 ? StatusColors.orange : StatusColors.green);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: pct,
            color: barColor,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            _miniLabel(context, 'On hand', n.onHand),
            _miniLabel(context, 'Forecast', n.forecast),
            _miniLabel(context, 'Min', n.minQty),
            if (n.maxQty > 0) _miniLabel(context, 'Max', n.maxQty),
          ],
        ),
      ],
    );
  }

  Widget _miniLabel(BuildContext context, String label, double value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      '$label: ${_qty(value)}',
      style: TextStyle(
        fontSize: 11,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required double value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
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
        children: List.generate(3, (i) => i)
            .map(
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 80,
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
