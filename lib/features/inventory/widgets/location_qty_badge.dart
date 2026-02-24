import 'package:flutter/material.dart';

class LocationQtyBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const LocationQtyBadge({super.key, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black87;
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    );
  }
}
