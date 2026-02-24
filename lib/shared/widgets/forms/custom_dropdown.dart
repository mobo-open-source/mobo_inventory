import 'package:flutter/material.dart';

/// A styled dropdown selector for picking a single value from a list of options.
class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final String labelText;
  final String? hintText;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool isDark;
  final List<DropdownMenuItem<T>> items;
  final bool enabled;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.labelText,
    required this.onChanged,
    required this.items,
    this.hintText,
    this.validator,
    this.isDark = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hintText != null
              ? Text(
                  hintText!,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xffF8FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff000000),
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
        ),
      ],
    );
  }
}
