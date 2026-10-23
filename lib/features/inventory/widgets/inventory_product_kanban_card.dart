import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';

/// Grid geometry shared by the kanban grid, its grouped variant and its
/// skeleton, so loading and loaded states line up.
class InventoryKanbanLayout {
  InventoryKanbanLayout._();

  /// Narrowest a card gets before a column is dropped.
  static const double minCardWidth = 168;
  static const double spacing = 12;
  static const double imageHeight = 96;

  /// Columns that fit [width]: 2 on a portrait phone, 3–4 on a landscape
  /// phone or portrait tablet, up to 6 on a landscape tablet.
  static int columnsFor(double width) {
    final fit = ((width + spacing) / (minCardWidth + spacing)).floor();
    return fit.clamp(2, 6);
  }

  /// Card height: the fixed image band plus the text block at the current
  /// text scale, so large accessibility fonts grow the card rather than
  /// overflow it.
  static double cardExtent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // name (2 lines @15) + reference (12) + quantity labels/values + price
    return imageHeight + 24 + scaler.scale(124);
  }

  static SliverGridDelegate delegate(BuildContext context, double width) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnsFor(width),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        mainAxisExtent: cardExtent(context),
      );
}

/// The row actions a product exposes on the list tile and the kanban card:
/// a menu of "Locate" and "Edit", or just an Edit button when "Edit" is the
/// only action left.
class InventoryProductActionsMenu extends StatelessWidget {
  final bool isDark;
  final bool canLocate;
  final VoidCallback? onLocate;
  final VoidCallback? onEdit;

  const InventoryProductActionsMenu({
    super.key,
    required this.isDark,
    required this.canLocate,
    this.onLocate,
    this.onEdit,
  });

  bool get _showLocate => canLocate && onLocate != null;

  /// False when the user has no action left on this product.
  bool get hasActions => _showLocate || onEdit != null;

  @override
  Widget build(BuildContext context) {
    // Nothing to offer: no menu trigger at all rather than an empty menu.
    if (!hasActions) return const SizedBox.shrink();
    // "Edit" alone: a button of its own, not a menu with a single entry.
    if (!_showLocate) {
      return SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          tooltip: 'Edit',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onEdit,
          icon: Icon(
            HugeIcons.strokeRoundedPencilEdit02,
            size: 20,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        tooltip: 'Actions',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: isDark ? Colors.white : Colors.black,
        ),
        onSelected: (value) {
          if (value == 'locate') {
            onLocate?.call();
          } else if (value == 'edit') {
            onEdit?.call();
          }
        },
        itemBuilder: (ctx) {
          final itemTextColor = isDark ? Colors.white : Colors.black87;
          return [
            if (_showLocate)
              PopupMenuItem<String>(
                value: 'locate',
                child: Text('Locate', style: TextStyle(color: itemTextColor)),
              ),
            if (onEdit != null)
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: itemTextColor)),
              ),
          ];
        },
      ),
    );
  }
}

/// A product in the inventory kanban grid — §11's border-only card: image
/// band, name in the brand colour, internal reference, on-hand / free
/// quantities and the sales price.
class InventoryProductKanbanCard extends StatelessWidget {
  final String name;
  final String? defaultCode;
  final double qtyOnHand;
  final double freeQty;
  final double listPrice;
  final String uomName;
  final Uint8List? imageBytes;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onLocate;

  /// The image beside the details rather than above them, sized by its
  /// content: Odoo's product card in a kanban column. The grid card needs
  /// the fixed height [InventoryKanbanLayout.cardExtent] instead.
  final bool compact;

  const InventoryProductKanbanCard({
    super.key,
    required this.name,
    this.defaultCode,
    required this.qtyOnHand,
    required this.freeQty,
    required this.listPrice,
    required this.uomName,
    this.imageBytes,
    required this.isDark,
    this.onTap,
    this.onEdit,
    this.onLocate,
    this.compact = false,
  });

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String? get _reference {
    final code = defaultCode?.trim();
    if (code == null ||
        code.isEmpty ||
        code.toLowerCase() == 'false' ||
        code.toLowerCase() == 'null') {
      return null;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final secondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final valueColor = isDark ? Colors.white : Colors.black87;

    if (compact) return _buildCompact(primary, secondary, valueColor);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: InventoryKanbanLayout.imageHeight,
                  child: _buildImage(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : primary,
                                ),
                              ),
                            ),
                            InventoryProductActionsMenu(
                              isDark: isDark,
                              canLocate: qtyOnHand != 0,
                              onLocate: onLocate,
                              onEdit: onEdit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _reference ?? 'No reference',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: secondary),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _stat(
                                  'On Hand',
                                  '${_qty(qtyOnHand)} $uomName',
                                  secondary,
                                  valueColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _stat(
                                  'Free to Use',
                                  '${_qty(freeQty)} $uomName',
                                  secondary,
                                  valueColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            listPrice.toStringAsFixed(2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: valueColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(Color primary, Color secondary, Color valueColor) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: SizedBox(width: 64, height: 64, child: _buildImage()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : primary,
                            ),
                          ),
                        ),
                        InventoryProductActionsMenu(
                          isDark: isDark,
                          canLocate: qtyOnHand != 0,
                          onLocate: onLocate,
                          onEdit: onEdit,
                        ),
                      ],
                    ),
                    if (_reference != null)
                      Text(
                        _reference!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'On Hand: ${_qty(qtyOnHand)} $uomName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: secondary),
                            ),
                          ),
                          Text(
                            listPrice.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: valueColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color labelColor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    final background = isDark ? Colors.grey[800] : Colors.grey[100];
    final fallback = Container(
      color: background,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[500],
        ),
      ),
    );

    final bytes = imageBytes;
    if (bytes == null || bytes.isEmpty) return fallback;
    return Container(
      color: isDark ? Colors.grey[800] : Colors.white,
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// §15 skeleton for the kanban grid: same shape, radius and border as
/// [InventoryProductKanbanCard], laid out with [InventoryKanbanLayout].
class InventoryProductKanbanShimmer extends StatelessWidget {
  final int itemCount;
  final EdgeInsets padding;

  const InventoryProductKanbanShimmer({
    super.key,
    this.itemCount = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[50]!;

    Widget bar(double width, double height, double radius) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        return GridView.builder(
          padding: padding,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: InventoryKanbanLayout.delegate(context, width),
          itemCount: itemCount,
          itemBuilder: (context, index) => DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: InventoryKanbanLayout.imageHeight,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(double.infinity, 14, 6),
                        const SizedBox(height: 8),
                        bar(70, 10, 4),
                        const SizedBox(height: 16),
                        bar(90, 10, 4),
                        const SizedBox(height: 8),
                        bar(50, 12, 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
