import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/warehouse_model.dart';
import 'warehouse_list_tile.dart';
import '../../../core/routing/app_routes.dart';

class WarehouseGroupTile extends StatefulWidget {
  final String groupKey;
  final int count;
  final List<Warehouse> items;
  final bool isDark;
  final ThemeData theme;

  const WarehouseGroupTile({
    super.key,
    required this.groupKey,
    required this.count,
    required this.items,
    required this.isDark,
    required this.theme,
  });

  @override
  State<WarehouseGroupTile> createState() => _WarehouseGroupTileState();
}

class _WarehouseGroupTileState extends State<WarehouseGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final theme = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.08),
            ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warehouse_outlined,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupKey,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.count} ${widget.count == 1 ? 'warehouse' : 'warehouses'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: widget.items
                    .map(
                      (w) => WarehouseListTile(
                        key: ValueKey(w.id),
                        warehouse: w,
                        isDark: isDark,
                        onTap: () {
                          context.pushNamed(
                            AppRoutes.warehouseDetail,
                            extra: {'warehouseId': w.id},
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
