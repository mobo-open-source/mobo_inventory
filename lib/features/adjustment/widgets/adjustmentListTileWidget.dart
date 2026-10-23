import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../models/inventory_adjustment_model.dart';

/// A list tile widget representing a single stock quant for inventory adjustment.
class AdjustmentListTile extends StatelessWidget {
  final InventoryAdjustment adjustment;
  final bool isDark;
  final VoidCallback onTap;
  final bool isInGroup;

  const AdjustmentListTile({
    super.key,
    required this.adjustment,
    required this.isDark,
    required this.onTap,
    this.isInGroup = false,
  });

  Color _getDifferenceColor() {
    if (adjustment.difference > 0) return StatusColors.green;
    if (adjustment.difference < 0) return StatusColors.red;
    return StatusColors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    adjustment.productName ?? 'Unknown Product',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInfoItem(
                    'Location',
                    adjustment.location ?? 'Unknown',
                    HugeIcons.strokeRoundedLocation05,
                    isDark ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: _buildInfoItem(
                    'On Hand',
                    adjustment.onHandQuantity.toStringAsFixed(2),
                    HugeIcons.strokeRoundedPackage,
                    isDark ? Colors.grey[400]! : Colors.grey[600]!,
                  ),
                ),
              ],
            ),

            if (adjustment.lotSerial != null) ...[
              const SizedBox(height: 8),
              _buildInfoItem(
                'Lot/Serial',
                adjustment.lotSerial!,
                Icons.qr_code_outlined,
                isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
