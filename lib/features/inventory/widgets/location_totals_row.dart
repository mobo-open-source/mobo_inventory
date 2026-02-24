import 'package:flutter/material.dart';

import '../../../core/const/app_colors.dart';

/// A widget displaying the total on-hand and reserved quantities for a list of locations.
class LocationTotalsRow extends StatelessWidget {
  final bool isDark;
  final double totalOnHand;
  final double totalReserved;
  const LocationTotalsRow({
    super.key,
    required this.isDark,
    required this.totalOnHand,
    required this.totalReserved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          const Expanded(flex: 8, child: _HeaderText('Total')),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                totalOnHand.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                totalReserved.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey[300] : Colors.grey[700],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
