import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/layout/collapsible_header_layout.dart';

/// A card widget displaying a single dashboard metric with an icon and
/// optional subtitle; tapping it opens the list the metric counts.
class DashboardStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String count;
  final String? subtitle;
  final VoidCallback onTap;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    this.subtitle,
    required this.onTap,
  });

  /// The grid the stat cards sit in, shared with their loading skeleton so
  /// the two line up: more columns as the screen widens. On a short screen
  /// (a phone in landscape) a width-derived tile would grow taller than the
  /// space left for it, so tiles are held at the height their content needs.
  ///
  /// Given the [itemCount], the cards of an incomplete last row share that
  /// row's width instead of leaving a gap beside them: a lone last card spans
  /// the whole row.
  static SliverGridDelegate gridDelegate(
    BuildContext context,
    double width, {
    int itemCount = 0,
  }) {
    final crossAxisCount = width >= 1000
        ? 4
        : width >= 600
        ? 3
        : 2;
    return _FillLastRowGridDelegate(
      itemCount: itemCount,
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      mainAxisExtent: isCompactHeight(context) ? 150 : null,
    );
  }

  /// Side of the tinted icon circle, shared with the loading skeleton. A
  /// notch smaller on a short screen, where the tile has no height to spare
  /// for the icon row.
  static double iconBoxSize(BuildContext context) =>
      isCompactHeight(context) ? 40 : 46;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final iconBox = iconBoxSize(context);

    final double countFont = width >= 1000
        ? 26
        : width >= 600
        ? 24
        : 22;

    final double titleFont = width >= 600 ? 14 : 13;
    final double subtitleFont = 12;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(isDark),
        // Count and icon share the first row, so the icon sits at the same
        // height on every card; the title and subtitle below then get the
        // card's full width instead of what the icon leaves them.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    count,
                    style: TextStyle(
                      fontSize: countFont,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: iconBox >= 46 ? 22 : 20, color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: titleFont,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: subtitleFont,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A fixed-column grid whose last row, when it is not full, is shared out
/// among the cards in it: every tile keeps the height of the others, but a
/// lone card spans the row, and two cards in a three-column row take half
/// each, instead of leaving an empty slot.
class _FillLastRowGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const _FillLastRowGridDelegate({
    required this.itemCount,
    required super.crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    super.childAspectRatio,
    super.mainAxisExtent,
  });

  final int itemCount;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final base = super.getLayout(constraints) as SliverGridRegularTileLayout;
    return _FillLastRowGridLayout(
      itemCount: itemCount,
      crossAxisCount: base.crossAxisCount,
      mainAxisStride: base.mainAxisStride,
      crossAxisStride: base.crossAxisStride,
      childMainAxisExtent: base.childMainAxisExtent,
      childCrossAxisExtent: base.childCrossAxisExtent,
      reverseCrossAxis: base.reverseCrossAxis,
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegateWithFixedCrossAxisCount old) =>
      super.shouldRelayout(old) ||
      (old is _FillLastRowGridDelegate && old.itemCount != itemCount);
}

class _FillLastRowGridLayout extends SliverGridRegularTileLayout {
  const _FillLastRowGridLayout({
    required this.itemCount,
    required super.crossAxisCount,
    required super.mainAxisStride,
    required super.crossAxisStride,
    required super.childMainAxisExtent,
    required super.childCrossAxisExtent,
    required super.reverseCrossAxis,
  });

  final int itemCount;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final inLastRow = itemCount % crossAxisCount;
    final firstOfLastRow = itemCount - inLastRow;
    // Full rows, and a last row that is full too, are the regular grid.
    if (inLastRow == 0 || index < firstOfLastRow || index >= itemCount) {
      return super.getGeometryForChildIndex(index);
    }

    final gap = crossAxisStride - childCrossAxisExtent;
    final rowWidth = crossAxisCount * childCrossAxisExtent +
        (crossAxisCount - 1) * gap;
    final width = (rowWidth - (inLastRow - 1) * gap) / inLastRow;
    final start = (index - firstOfLastRow) * (width + gap);

    return SliverGridGeometry(
      scrollOffset: (index ~/ crossAxisCount) * mainAxisStride,
      crossAxisOffset: reverseCrossAxis ? rowWidth - start - width : start,
      mainAxisExtent: childMainAxisExtent,
      crossAxisExtent: width,
    );
  }
}
