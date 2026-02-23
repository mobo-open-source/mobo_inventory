import 'package:flutter/material.dart';
import '../models/replenishment_orderpoint.dart';

class ReplenishmentListTile extends StatelessWidget {
  final ReplenishmentOrderpoint item;
  final bool isDark;
  final VoidCallback? onOrder;
  final VoidCallback? onAutomate;
  final VoidCallback? onSnooze;
  final VoidCallback? onEdit;

  const ReplenishmentListTile({
    super.key,
    required this.item,
    required this.isDark,
    this.onOrder,
    this.onAutomate,
    this.onSnooze,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.06),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.productName.isNotEmpty ? item.productName : '-/-',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.trigger != 'auto')
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: _actionsPill(context, isDark),
                  ),
              ],
            ),

            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.locationName.isNotEmpty ? item.locationName : '—',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _metricRow(context, isDark, 'On Hand', item.onHand)),
                      const SizedBox(width: 8),
                      Expanded(child: _metricRow(context, isDark, 'Forecast', item.forecast)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _metricSmall(context, isDark, 'Min', item.minQty)),
                      const SizedBox(width: 8),
                      Expanded(child: _metricSmall(context, isDark, 'Max', item.maxQty)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metricSmall(
                          context,
                          isDark,
                          'To Order',
                          item.toOrder,
                          highlight: true,
                          alignRight: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(BuildContext context, bool isDark, String label, double value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.tight,
          child: Text(
            value.toStringAsFixed(2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _metricSmall(
    BuildContext context,
    bool isDark,
    String label,
    double value, {
    bool highlight = false,
    bool alignRight = false,
  }) {
    final theme = Theme.of(context);
    final color = highlight ? theme.colorScheme.primary : (isDark ? Colors.grey[300] : Colors.grey[800]);
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }

  Widget _actionsPill(BuildContext context, bool isDark) {

    final iconColor = isDark ? Colors.white : Colors.black;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      splashRadius: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? Colors.grey[900] : Colors.white,
      icon: Icon(Icons.more_vert, color: iconColor, size: 20),
      onSelected: (val) {
        switch (val) {
          case 'order':
            onOrder?.call();
            break;
          case 'auto':
            onAutomate?.call();
            break;
          case 'snooze':
            onSnooze?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'order',
          child: Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 18, color: iconColor),
              const SizedBox(width: 8),
              const Text('Order'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'auto',
          child: Row(
            children: [
              Icon(Icons.autorenew, size: 18, color: iconColor),
              const SizedBox(width: 8),
              const Text('Automate'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'snooze',
          child: Row(
            children: [
              Icon(Icons.snooze_outlined, size: 18, color: iconColor),
              const SizedBox(width: 8),
              const Text('Snooze'),
            ],
          ),
        ),
      ],
    );
  }
}
