import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: widget.theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconForGroup(),
                      color: widget.theme.primaryColor,
                      size: 22,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.adjustments.length} adjustment${widget.adjustments.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 14,
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
                    color: widget.isDark ? Colors.white70 : Colors.black87,
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
