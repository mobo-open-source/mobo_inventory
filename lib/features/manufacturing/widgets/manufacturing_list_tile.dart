import 'package:flutter/material.dart';
import '../models/manufacturing_transfer_model.dart';

class ManufacturingListTile extends StatelessWidget {
  final ManufacturingTransfer item;
  final bool isDark;
  final VoidCallback? onTap;

  const ManufacturingListTile({super.key, required this.item, required this.isDark, this.onTap});

  Color _stateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.orange;
      case 'confirmed':
      case 'planned':
        return Colors.blue;
      case 'progress':
        return Colors.teal;
      case 'to_close':
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _stateLabel(item.state),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if ((item.productName ?? '').isNotEmpty)
              Text(
                'Product: ${item.productName}',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.productQty != null)
                  Expanded(
                    child: Text(
                      'Qty: ${item.productQty!.toStringAsFixed(0)} ${item.uomName ?? ''}',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if ((item.scheduledDate ?? '').isNotEmpty)
                  Expanded(
                    child: Text(
                      'Planned: ${item.scheduledDate}',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
