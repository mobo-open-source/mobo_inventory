import 'package:flutter/material.dart';

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
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoading ? 'Loading…' : '$count scheduled today',
                      style: TextStyle(
                        fontSize: 12,
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
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
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
                      color: Colors.green,
                      icon: Icons.call_received_outlined,
                      onTap: onTapIncoming,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: tile(
                      title: 'Outgoing Deliveries',
                      count: outgoingCount,
                      color: Colors.orange,
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
                    color: Colors.green,
                    icon: Icons.call_received_outlined,
                    onTap: onTapIncoming,
                  ),
                  const SizedBox(height: 12),
                  tile(
                    title: 'Outgoing Deliveries',
                    count: outgoingCount,
                    color: Colors.orange,
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
