import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/access_rights_service.dart';
import '../../../core/theme/app_theme.dart';
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

  // Odoo's list shows "Order" only while there is something to order,
  // "Automate" only for manual rules with something to order, and
  // "Snooze" only for manual rules.
  bool get _canOrder => item.toOrder > 0;
  bool get _isManual => item.trigger != 'auto';

  /// Every action — Order, Automate, Snooze, editing the values — writes the
  /// orderpoint, so without write access the tile is read-only.
  bool _hasActions(bool canWrite) => canWrite && (_canOrder || _isManual);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canWrite = context.watch<AccessRightsService>().can(
      'stock.warehouse.orderpoint',
      'write',
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                if (_hasActions(canWrite))
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
              onTap: canWrite ? onEdit : null,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Both rows share one three-column grid (left / centre /
                  // right) so each metric sits directly above or below the
                  // one in the same column.
                  Row(
                    children: [
                      Expanded(
                        child: _metric(
                          context,
                          isDark,
                          'On Hand',
                          item.onHand,
                          highlight: true,
                        ),
                      ),
                      Expanded(
                        child: _metric(
                          context,
                          isDark,
                          'Forecast',
                          item.forecast,
                          highlight: true,
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _metric(context, isDark, 'Min', item.minQty),
                      ),
                      Expanded(
                        child: _metric(
                          context,
                          isDark,
                          'Max',
                          item.maxQty,
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                      Expanded(
                        child: _metric(
                          context,
                          isDark,
                          item.uomName.isNotEmpty
                              ? 'To Order (${item.uomName})'
                              : 'To Order',
                          item.toOrder,
                          highlight: true,
                          align: CrossAxisAlignment.end,
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

  /// A label over its value. [align] picks the column edge the text hugs
  /// (start / center / end); [highlight] uses the brand colour for the value.
  Widget _metric(
    BuildContext context,
    bool isDark,
    String label,
    double value, {
    bool highlight = false,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    final textAlign = switch (align) {
      CrossAxisAlignment.end => TextAlign.right,
      CrossAxisAlignment.center => TextAlign.center,
      _ => TextAlign.left,
    };
    final valueColor = highlight
        ? Theme.of(context).primaryColor
        : (isDark ? Colors.grey[300] : Colors.grey[800]);
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _actionsPill(BuildContext context, bool isDark) {
    final iconColor = isDark ? Colors.white : Colors.black;
    final itemTextColor = isDark ? Colors.white : Colors.black87;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      splashRadius: 18,
      position: PopupMenuPosition.under,
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
        if (_canOrder)
          PopupMenuItem(
            value: 'order',
            child: Text('Order', style: TextStyle(color: itemTextColor)),
          ),
        if (_canOrder && _isManual)
          PopupMenuItem(
            value: 'auto',
            child: Text('Automate', style: TextStyle(color: itemTextColor)),
          ),
        if (_isManual)
          PopupMenuItem(
            value: 'snooze',
            child: Text('Snooze', style: TextStyle(color: itemTextColor)),
          ),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
