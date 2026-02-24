import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/move_history_item.dart';

class MoveHistoryListTile extends StatelessWidget {
  final MoveHistoryItem item;
  final bool isDark;
  final VoidCallback? onTap;
  
  const MoveHistoryListTile({super.key, required this.item, required this.isDark, this.onTap});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    item.reference ?? 'No Reference',
                    style: TextStyle(
                      fontSize: 15,
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
                    color: _getStatusColor(item.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(item.status),
                    style: TextStyle(
                      color: _getStatusColor(item.status),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (item.product != null) ...[
              const SizedBox(height: 6),
              Text(
                item.product!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: 6),

            Row(
              children: [

                Expanded(
                  flex: 2,
                  child: _buildInfoItem(
                    'Quantity',
                    item.quantity.toStringAsFixed(2),
                    HugeIcons.strokeRoundedTask01,
                    isDark ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),

                if (item.fromLocation != null || item.toLocation != null)
                  Expanded(
                    flex: 3,
                    child: _buildInfoItem(
                      'Movement',
                      _getLocationText(),
                      Icons.swap_horiz,
                      isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  String _getLocationText() {
    if (item.fromLocation != null && item.toLocation != null) {
      return '${item.fromLocation} → ${item.toLocation}';
    } else if (item.fromLocation != null) {
      return 'From: ${item.fromLocation}';
    } else if (item.toLocation != null) {
      return 'To: ${item.toLocation}';
    }
    return 'No location';
  }

  Widget _buildInfoItem(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: iconColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String? state) {
    switch (state) {
      case 'draft':

        return Colors.grey;
      case 'waiting':

        return Colors.tealAccent;
      case 'confirmed':

        return Colors.orange;
      case 'partially_available':

        return Colors.deepOrange;
      case 'assigned':

        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusLabel(String? state) {
    switch (state) {
      case 'draft':
        return 'New';
      case 'waiting':
        return 'Waiting Another Move';
      case 'confirmed':
        return 'Waiting Availability';
      case 'partially_available':
        return 'Partially Available';
      case 'assigned':
        return 'Available';
      case 'done':
        return 'Done';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}
