import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'adjustmentListTileWidget.dart';

/// A widget that groups multiple [AdjustmentListTile] items under a collectible header.
class AdjustmentGroupTile extends StatefulWidget {
  final String groupKey;
  final List<dynamic> adjustments;
  final bool isDark;
  final ThemeData theme;
  final Function(dynamic) onAdjustmentTap;

  const AdjustmentGroupTile({
    super.key,
    required this.groupKey,
    required this.adjustments,
    required this.isDark,
    required this.theme,
    required this.onAdjustmentTap,
  });

  @override
  State<AdjustmentGroupTile> createState() => _AdjustmentGroupTileState();
}

class _AdjustmentGroupTileState extends State<AdjustmentGroupTile> {
  bool _expanded = false;

  IconData _iconForGroup() {
    final key = widget.groupKey.toLowerCase();
    if (key.contains('location')) {
      return HugeIcons.strokeRoundedLocation01;
    }
    if (key.contains('product') || key.contains('category')) {
      return HugeIcons.strokeRoundedLayersLogo;
    }
    if (key.contains('company')) {
      return HugeIcons.strokeRoundedBuilding01;
    }
    if (key.contains('lot') || key.contains('serial')) {
      return Icons.qr_code;
    }
    return HugeIcons.strokeRoundedLayersLogo;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!widget.isDark)
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
                      color: widget.theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconForGroup(),
                      color: widget.theme.primaryColor,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.adjustments.length} adjustment${widget.adjustments.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            for (final adjustment in widget.adjustments)
              GestureDetector(
                key: ValueKey(adjustment.id),
                onTap: () => widget.onAdjustmentTap(adjustment),
                child: AdjustmentListTile(
                  adjustment: adjustment,
                  isDark: widget.isDark,
                  onTap: () => widget.onAdjustmentTap(adjustment),
                  isInGroup: true,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
