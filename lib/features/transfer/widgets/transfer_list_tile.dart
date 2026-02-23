import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/transfer_model.dart';
import '../utils/transfer_state_helper.dart';

/// A list tile widget representing a single stock transfer in a list.
class TransferListTile extends StatelessWidget {
  final InternalTransfer transfer;
  final bool isDark;
  final VoidCallback? onTap;

  const TransferListTile({
    super.key,
    required this.transfer,
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
                    transfer.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: TransferStateHelper.getStateColor(
                      transfer.state,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    TransferStateHelper.getStateLabel(transfer.state),
                    style: TextStyle(
                      color: TransferStateHelper.getStateColor(transfer.state),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (transfer.locationName != null &&
                transfer.locationDestName != null)
              Row(
                children: [
                  const Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: Color(0xFF9E9E9E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Route: ${transfer.locationName} → ${transfer.locationDestName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            if (transfer.locationName != null &&
                transfer.locationDestName != null)
              const SizedBox(height: 4),
            Row(
              children: [
                if (transfer.scheduledDate != null)
                  Icon(
                    HugeIcons.strokeRoundedCalendar03,
                    size: 14,
                    color: isDark ? Colors.grey[100] : const Color(0xffC5C5C5),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Date: ${transfer.scheduledDate!}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                if (transfer.moveLines.isNotEmpty)
                  Text(
                    '${transfer.moveLines.length} item(s)',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
