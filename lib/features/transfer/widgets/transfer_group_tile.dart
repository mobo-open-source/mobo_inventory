import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/transfer_model.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
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
    // §12 grouped section header shell.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // grey[900] in dark so the grey[850] cards nested in the group stay
        // visible.
        color: widget.isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.groupKey,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  StatusColors.buildStatusBadge(
                    '${widget.count}',
                    widget.theme.primaryColor,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
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
