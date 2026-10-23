import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class OperationsTodaySummary extends StatelessWidget {
  final int incomingCount;
  final int outgoingCount;
  final bool isLoading;
  final VoidCallback? onTapIncoming;
  final VoidCallback? onTapOutgoing;

  const OperationsTodaySummary({
    super.key,
    required this.incomingCount,
    required this.outgoingCount,
    this.isLoading = false,
    this.onTapIncoming,
    this.onTapOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile({
      required String title,
      required int count,
      required Color color,
      required IconData icon,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(isDark),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoading ? 'Loading…' : '$count scheduled today',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Operations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: tile(
                      title: 'Incoming Shipments',
                      count: incomingCount,
                      color: StatusColors.green,
                      icon: Icons.call_received_outlined,
                      onTap: onTapIncoming,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: tile(
                      title: 'Outgoing Deliveries',
                      count: outgoingCount,
                      color: StatusColors.orange,
                      icon: Icons.call_made_outlined,
                      onTap: onTapOutgoing,
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tile(
                    title: 'Incoming Shipments',
                    count: incomingCount,
                    color: StatusColors.green,
                    icon: Icons.call_received_outlined,
                    onTap: onTapIncoming,
                  ),
                  const SizedBox(height: 12),
                  tile(
                    title: 'Outgoing Deliveries',
                    count: outgoingCount,
                    color: StatusColors.orange,
                    icon: Icons.call_made_outlined,
                    onTap: onTapOutgoing,
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }
}
