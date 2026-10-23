import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/manufacturing_transfer_model.dart';

class ManufacturingListTile extends StatelessWidget {
  final ManufacturingTransfer item;
  final bool isDark;
  final VoidCallback? onTap;

  const ManufacturingListTile({
    super.key,
    required this.item,
    required this.isDark,
    this.onTap,
  });

  Color _stateColor(String state) => StatusColors.forState(state);

  String _stateLabel(String state) {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'confirmed':
        return 'Confirmed';
      case 'planned':
        return 'Planned';
      case 'progress':
        return 'In Progress';
      case 'to_close':
        return 'To Close';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _stateColor(item.state);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusColors.buildStatusBadge(
                  _stateLabel(item.state),
                  color,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 2),
            if ((item.productName ?? '').isNotEmpty)
              Text(
                'Product: ${item.productName}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.productQty != null)
                  Expanded(
                    child: Text(
                      'Qty: ${item.productQty!.toStringAsFixed(0)} ${item.uomName ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if ((item.scheduledDate ?? '').isNotEmpty)
                  Expanded(
                    child: Text(
                      'Planned: ${item.scheduledDate}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
