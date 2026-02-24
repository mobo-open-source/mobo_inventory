import 'package:flutter/material.dart';
import '../models/picking_model.dart';

class PickingListTile extends StatelessWidget {
  final Picking picking;
  final bool isDark;
  final VoidCallback? onTap;

  const PickingListTile({
    super.key,
    required this.picking,
    required this.isDark,
    this.onTap,
  });

  Color _stateColor(String state, BuildContext context) {
    switch (state) {
      case 'draft':
      case 'waiting':
      case 'confirmed':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'waiting':
        return 'Waiting';
      case 'confirmed':
        return 'To Do';
      case 'assigned':
        return 'Ready';
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
    final color = _stateColor(picking.state, context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    picking.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _stateLabel(picking.state),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if ((picking.origin ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Origin: ${picking.origin}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            const SizedBox(height: 4),

            if ((picking.partnerName ?? '').isNotEmpty)
              Text(
                'Partner: ${picking.partnerName}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            const SizedBox(height: 4),
            Text(
              'Scheduled: ${picking.scheduledDate}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
