import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A tile widget displaying stock quantity information for a specific location.
class LocationTile extends StatelessWidget {
  final bool isDark;
  final String locationName;
  final String productName;
  final double onHandQty;
  final double reservedQty;

  const LocationTile({
    super.key,
    required this.isDark,
    required this.locationName,
    required this.productName,
    required this.onHandQty,
    required this.reservedQty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: AppTheme.cardDecoration(isDark),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 520;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: _CellText(locationName, isDark: isDark, bold: true),
              ),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.center,
                  child: _CellText(productName, isDark: isDark),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.center,
                  child: _QtyText(_formatQty(onHandQty), color: primary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.center,
                  child: _QtyText(_formatQty(reservedQty), color: primary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatQty(double v) => v.toStringAsFixed(2);
}

class _CellText extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool bold;

  const _CellText(this.text, {required this.isDark, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}

class _QtyText extends StatelessWidget {
  final String text;
  final Color color;

  const _QtyText(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
    );
  }
}
