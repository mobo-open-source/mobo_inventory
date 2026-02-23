import 'package:flutter/material.dart';

/// A custom-styled chip widget used for toggleable filter options.
class FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return FilterChip(
      selected: isSelected,
      onSelected: onSelected,

      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),

      backgroundColor: isDark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFFCE4EC),
      selectedColor: primaryColor,

      showCheckmark: true,
      checkmarkColor: Colors.white,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1,
        ),
      ),

      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),

      elevation: 0,
      pressElevation: 0,
    );
  }
}
