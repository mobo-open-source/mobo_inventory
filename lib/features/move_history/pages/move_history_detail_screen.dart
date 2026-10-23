import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cards/status_info_card.dart';
import '../models/move_history_item.dart';

/// A screen providing granular details for a specific stock movement (move line).
///
/// Displays precise quantity changes, lot/serial information, and status
/// with clear indicators for positive/negative stock impacts.
class MoveHistoryDetailScreen extends StatelessWidget {
  final MoveHistoryItem item;

  const MoveHistoryDetailScreen({super.key, required this.item});

  Color _qtyColor(double q) => q > 0
      ? StatusColors.green
      : q < 0
      ? StatusColors.red
      : StatusColors.grey;

  String _statusLabel(String? state) {
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
        return state?.toUpperCase() ?? '-';
    }
  }

  Color _statusColor(String? state) => StatusColors.forState(state);

  Widget _row(
    BuildContext context, {
    IconData? icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final qtyColor = item.quantity < 0 ? StatusColors.red : StatusColors.green;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Move Details',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StatusInfoCard(
              title: item.product ?? 'Unknown product',
              subtitle: item.reference ?? '-',
              statusLabel: _statusLabel(item.status),
              statusColor: _statusColor(item.status),
              fields: [
                StatusInfoField(
                  icon: Icons.scale,
                  label: 'Quantity',
                  value:
                      '${item.quantity >= 0 ? '+' : ''}${item.quantity.toStringAsFixed(2)}',
                ),
                StatusInfoField(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: 'Date',
                  value:
                      item.date?.toLocal().toString().substring(0, 16) ?? '-',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),

            _buildInfoCard(
              isDark,
              children: [
                Text(
                  'Locations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _row(context, label: 'From', value: item.fromLocation ?? '-'),
                const SizedBox(height: 12),
                _row(context, label: 'To', value: item.toLocation ?? '-'),
              ],
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              isDark,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _row(
                        context,
                        icon: Icons.inventory_2_outlined,
                        label: 'Product',
                        value: item.product ?? '-',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _row(
                        context,
                        icon: HugeIcons.strokeRoundedTask01,
                        label: 'Lot/Serial',
                        value: item.lotSerial ?? '-',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              isDark,
              backgroundColor: Color.alphaBlend(
                isDark
                    ? StatusColors.backgroundDark(qtyColor)
                    : StatusColors.backgroundLight(qtyColor),
                isDark ? AppTheme.darkSurface : Colors.white,
              ),
              borderColor: qtyColor,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: qtyColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.quantity >= 0
                            ? 'Positive quantity indicates stock coming into internal/transit location.'
                            : 'Negative quantity indicates stock leaving internal/transit location.',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark, {
    required List<Widget> children,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? (isDark ? AppTheme.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: AppShadows.panel(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
