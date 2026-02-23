import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/transfer_model.dart';
import '../../../core/routing/app_routes.dart';
import 'transfer_list_tile.dart';

class TransferGroupTile extends StatefulWidget {
  final String groupKey;
  final int count;
  final List<InternalTransfer> items;
  final bool isDark;
  final ThemeData theme;

  const TransferGroupTile({
    super.key,
    required this.groupKey,
    required this.count,
    required this.items,
    required this.isDark,
    required this.theme,
  });

  @override
  State<TransferGroupTile> createState() => _TransferGroupTileState();
}

class _TransferGroupTileState extends State<TransferGroupTile> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.groupKey,
                      style: widget.theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.theme.iconTheme.color,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: widget.items
                    .map(
                      (item) => GestureDetector(
                        onTap: () {
                          context.pushNamed(
                            AppRoutes.transferDetail,
                            extra: item,
                          );
                        },
                        child: TransferListTile(
                          transfer: item,
                          isDark: widget.isDark,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
