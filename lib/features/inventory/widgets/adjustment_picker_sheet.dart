import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../adjustment/models/inventory_adjustment_model.dart';

/// "Select Location / Lot": picks which of a product's stock quants to count
/// when it has more than one.
///
/// A §19 bottom sheet that stays inside a short landscape screen: capped to
/// the screen height, clear of the notch (`useSafeArea`), at most 640 wide,
/// and with the list scrolling under a pinned title; when even the title
/// would crowd the list out, the whole sheet scrolls. Pops the chosen
/// [InventoryAdjustment], or null when dismissed.
class AdjustmentPickerSheet extends StatelessWidget {
  final List<InventoryAdjustment> adjustments;

  const AdjustmentPickerSheet({super.key, required this.adjustments});

  static const double maxWidth = 640;

  /// Below this the pinned handle + title would leave the list no room.
  static const double _minHeightForPinnedHeader = 200;

  static Future<InventoryAdjustment?> show(
    BuildContext context, {
    required List<InventoryAdjustment> adjustments,
  }) {
    return showModalBottomSheet<InventoryAdjustment>(
      context: context,
      // The sheet's own Container supplies the background and radius (§19).
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: maxWidth),
      builder: (_) => AdjustmentPickerSheet(adjustments: adjustments),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    // Room left by the safe area; a landscape phone has little, so the
    // sheet may use most of it there.
    final heightCap = media.size.height * (isLandscape ? 0.9 : 0.6);
    final bottomInset = media.padding.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: heightCap),
      // A Material rather than a decorated box, so the rows' ink splashes
      // show on it.
      child: Material(
        color: isDark ? AppTheme.darkSurface : Colors.grey[50],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final header = _buildHeader(context, isDark);

            if (constraints.maxHeight < _minHeightForPinnedHeader) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomInset + 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    for (var i = 0; i < adjustments.length; i++) ...[
                      if (i > 0) _divider(isDark),
                      _buildItem(context, adjustments[i], isDark),
                    ],
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Flexible(
                  child: ListView.separated(
                    key: const ValueKey('adjustmentPickerList'),
                    shrinkWrap: true,
                    padding: EdgeInsets.only(bottom: bottomInset + 8),
                    itemCount: adjustments.length,
                    separatorBuilder: (_, __) => _divider(isDark),
                    itemBuilder: (context, i) =>
                        _buildItem(context, adjustments[i], isDark),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // §19 drag handle.
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Select Location / Lot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(bool isDark) =>
      Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12);

  Widget _buildItem(BuildContext context, InventoryAdjustment a, bool isDark) {
    final lot = a.lotSerial?.trim();
    final onHand = 'On hand: ${a.onHandQuantity.toStringAsFixed(2)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        a.location ?? 'Unknown Location',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        (lot != null && lot.isNotEmpty) ? 'Lot: $lot  ·  $onHand' : onHand,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      onTap: () => Navigator.of(context).pop(a),
    );
  }
}
