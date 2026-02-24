import 'package:flutter/material.dart';
import '../models/replenishment_need.dart';

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
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            if (onSeeAll != null)
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading && items.isEmpty)
          _shimmerList(context)
        else if (items.isEmpty)
          _emptyState(isDark)
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
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) => SizedBox(width: 280, child: _tile(context, items[i])),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _emptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Text(
        'All products are above minimum stock',
        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
    );
  }

  Widget _tile(BuildContext context, ReplenishmentNeed n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shortage = n.shortage;
    final shortageColor = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(10),
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
              color: shortageColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined, color: shortageColor, size: 18),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                _stockLevelBar(context, n),
              ],
            ),
          ),
          const SizedBox(width: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${shortage.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: shortageColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Shortage',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockLevelBar(BuildContext context, ReplenishmentNeed n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double target = n.maxQty > 0 ? n.maxQty : (n.minQty > 0 ? n.minQty : 1);
    final double pct = (n.onHand / target).clamp(0.0, 1.0);
    final Color barColor = n.onHand < n.minQty
        ? Colors.redAccent
        : (pct < 0.5 ? Colors.orange : Colors.green);
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
            _miniLabel(context, 'Min', n.minQty),
            if (n.maxQty > 0) _miniLabel(context, 'Max', n.maxQty),
          ],
        )
      ],
    );
  }

  Widget _miniLabel(BuildContext context, String label, double value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      '$label: ${value.toStringAsFixed(0)}',
      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
    );
  }

  Widget _chip(BuildContext context, {required String label, required double value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value.toStringAsFixed(0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _shimmerList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: List.generate(3, (i) => i)
          .map((_) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 72,
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
