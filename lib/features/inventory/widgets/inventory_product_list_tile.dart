import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A list tile representing a single product in the inventory product list.
class InventoryProductListTile extends StatelessWidget {
  final String id;
  final String name;
  final String? defaultCode;
  final String? barcode;
  final double qtyOnHand;
  final double qtyIncoming;
  final double qtyOutgoing;
  final double qtyAvailable;
  final double freeQty;
  final double avgCost;
  final double totalValue;
  final String uomName;
  final String? category;
  final Uint8List? imageBytes;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onLocate;

  const InventoryProductListTile({
    super.key,
    required this.id,
    required this.name,
    this.defaultCode,
    this.barcode,
    required this.qtyOnHand,
    required this.qtyIncoming,
    required this.qtyOutgoing,
    required this.qtyAvailable,
    required this.freeQty,
    required this.avgCost,
    required this.totalValue,
    required this.uomName,
    this.category,
    this.imageBytes,
    required this.isDark,
    this.onTap,
    this.onEdit,
    this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 12,
              top: 12,
              bottom: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : theme.primaryColor,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuantityInfo(
                              'Unit Cost',
                              avgCost,
                              theme.primaryColor,
                              isCurrency: true,
                            ),
                          ),
                          Expanded(
                            child: _buildQuantityInfo(
                              'Total Value',
                              totalValue,
                              theme.primaryColor,
                              isCurrency: true,
                            ),
                          ),
                          Expanded(
                            child: _buildQuantityInfo(
                              'On Hand',
                              qtyOnHand,
                              theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuantityInfo(
                              'Free to Use',
                              freeQty,
                              theme.primaryColor,
                            ),
                          ),
                          Expanded(
                            child: _buildQuantityInfo(
                              'Incoming',
                              qtyIncoming,
                              theme.primaryColor,
                            ),
                          ),
                          Expanded(
                            child: _buildQuantityInfo(
                              'Outgoing',
                              qtyOutgoing,
                              theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: buildTrailingActions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityInfo(
    String label,
    double quantity,
    Color color, {
    bool isCurrency = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isCurrency
              ? quantity.toStringAsFixed(2)
              : '${quantity.toStringAsFixed(0)} $uomName',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage() {
    final hasRenderableImage = _isRenderableRaster(imageBytes);

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasRenderableImage
            ? Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    Center(child: _buildAvatarFallback()),
              )
            : Center(child: _buildAvatarFallback()),
      ),
    );
  }

  bool _isRenderableRaster(Uint8List? bytes) {
    if (bytes == null || bytes.length < 4) return false;

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }

    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;

    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;

    if (bytes.length >= 12) {
      final riff =
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46;
      final webp =
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50;
      if (riff && webp) return true;
    }

    return false;
  }

  Widget _buildAvatarFallback() {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      first,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  String _getDisplaySku() {
    if (defaultCode != null &&
        defaultCode!.trim().isNotEmpty &&
        defaultCode!.toLowerCase() != 'false' &&
        defaultCode!.toLowerCase() != 'null') {
      return defaultCode!;
    }
    return '—';
  }

  Widget buildTrailingActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final leftBgColor = (isDark
        ? colorScheme.primary.withOpacity(0.22)
        : colorScheme.primary.withOpacity(0.16));
    final showLocate = qtyOnHand != 0;

    return SizedBox(
      height: 30,
      child: PopupMenuButton<String>(
        tooltip: 'Actions',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDark ? Colors.grey[900] : Colors.white,
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: isDark ? Colors.white : Colors.black,
        ),
        onSelected: (value) {
          if (value == 'locate' && onLocate != null) {
            onLocate!();
          } else if (value == 'edit' && onEdit != null) {
            onEdit!();
          }
        },
        itemBuilder: (ctx) {
          final iconColor = isDark ? Colors.white : Colors.black;
          final List<PopupMenuEntry<String>> items = [];
          if (showLocate && onLocate != null) {
            items.add(
              PopupMenuItem<String>(
                value: 'locate',
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    const Text('Locate'),
                  ],
                ),
              ),
            );
          }
          if (onEdit != null) {
            items.add(
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedPencilEdit02,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    const Text('Edit'),
                  ],
                ),
              ),
            );
          }
          if (items.isEmpty) {
            items.add(
              const PopupMenuItem<String>(
                value: 'none',
                enabled: false,
                child: Text('No actions'),
              ),
            );
          }
          return items;
        },
      ),
    );
  }
}
