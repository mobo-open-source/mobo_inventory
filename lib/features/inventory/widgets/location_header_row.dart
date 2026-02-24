import 'package:flutter/material.dart';

/// A widget displaying a table header for location stock lists.
class LocationHeaderRow extends StatelessWidget {
  final bool isDark;

  const LocationHeaderRow({super.key, required this.isDark});

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
        children: const [
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.center,
              child: _HeaderText('Location'),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.center,
              child: _HeaderText('Product'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: _HeaderText('On Hand'),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: _HeaderText('Reserved'),
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
