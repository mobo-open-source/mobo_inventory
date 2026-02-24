import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/warehouse_model.dart';

class WarehouseListTile extends StatelessWidget {
  final Warehouse warehouse;
  final bool isDark;
  final VoidCallback? onTap;

  const WarehouseListTile({
    super.key,
    required this.warehouse,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    warehouse.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (warehouse.code != null && warehouse.code!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      warehouse.code!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (warehouse.companyName != null) ...[
                  Expanded(
                    child: _buildInfoItem(
                      'Company',
                      warehouse.companyName!,
                      HugeIcons.strokeRoundedBuilding05,
                      isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                ],
                if (warehouse.lotStockName != null) ...[
                  Expanded(
                    child: _buildInfoItem(
                      'Stock Location',
                      warehouse.lotStockName!,
                      HugeIcons.strokeRoundedLocation05,
                      isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
