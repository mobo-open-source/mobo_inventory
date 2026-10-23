import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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

  Color _stateColor(String state, BuildContext context) =>
      StatusColors.forState(state);

  String _stateLabel(String state) {
    switch (state) {
      case 'draft':
        return 'Draft';
      case 'waiting':
        return 'Waiting';
      case 'confirmed':
        return 'Waiting';
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
                    picking.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                StatusColors.buildStatusBadge(
                  _stateLabel(picking.state),
                  color,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 6),
            _detailLine('Origin', picking.origin),
            const SizedBox(height: 4),
            _detailLine('Partner', picking.partnerName),
            const SizedBox(height: 4),
            _detailLine('Scheduled', picking.scheduledDate),
          ],
        ),
      ),
    );
  }

  /// A "Label: value" line, with "-" when Odoo has no value for it.
  Widget _detailLine(String label, String? value) {
    final text = (value ?? '').trim();
    return Text(
      '$label: ${text.isEmpty ? '-' : text}',
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
