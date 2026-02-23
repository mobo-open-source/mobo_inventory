import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/transfer_model.dart';
import '../providers/transfer_provider.dart';
import '../utils/transfer_state_helper.dart';

class _GroupTile extends StatefulWidget {
  final String groupKey;
  final int count;
  final List<dynamic> loadedTransfers;
  final TransferProvider provider;
  final bool isDark;
  final ThemeData theme;

  const _GroupTile({
    required this.groupKey,
    required this.count,
    required this.loadedTransfers,
    required this.provider,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  bool _isExpanded = false;

  IconData _getGroupIcon() {
    switch (widget.provider.selectedGroupBy) {
      case 'state':
        return HugeIcons.strokeRoundedCheckmarkCircle02;
      case 'picking_type_id':
        return HugeIcons.strokeRoundedArrowDataTransferHorizontal;
      case 'location_id':
        return HugeIcons.strokeRoundedLocation01;
      case 'location_dest_id':
        return HugeIcons.strokeRoundedLocation03;
      default:
        return HugeIcons.strokeRoundedLayersLogo;
    }
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
            )
        ],
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              setState(() {
                _isExpanded = !_isExpanded;
              });

              if (_isExpanded && widget.loadedTransfers.isEmpty) {
                await widget.provider.loadGroupTransfers(widget.groupKey);
              }
            },
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
                      _getGroupIcon(),
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
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.count} transfer${widget.count != 1 ? 's' : ''}',
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
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(
              height: 1,
              color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            if (widget.loadedTransfers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...widget.loadedTransfers.map((transfer) {
                if (transfer is InternalTransfer) {
                  return _TransferListTile(
                    transfer: transfer,
                    isDark: widget.isDark,
                    onTap: () {

                    },
                    isInGroup: true,
                  );
                }
                return const SizedBox.shrink();
              }),
          ],
        ],
      ),
    );
  }
}

class _TransferListTile extends StatelessWidget {
  final InternalTransfer transfer;
  final bool isDark;
  final VoidCallback onTap;
  final bool isInGroup;

  const _TransferListTile({
    required this.transfer,
    required this.isDark,
    required this.onTap,
    this.isInGroup = false,
  });

  Color _getStateColor() {
    return TransferStateHelper.getStateColor(transfer.state);
  }

  String _getStateLabel() {
    return TransferStateHelper.getStateLabel(transfer.state);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isInGroup
              ? Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transfer.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStateColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStateLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getStateColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  HugeIcons.strokeRoundedLocation01,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${transfer.locationName ?? 'Unknown'} → ${transfer.locationDestName ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
