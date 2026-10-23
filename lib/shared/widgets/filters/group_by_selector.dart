import 'package:flutter/material.dart';

/// A single selectable option in a [GroupBySelector].
///
/// A [value] of `null` means "no grouping" (the "None" option).
class GroupByOption {
  final String title;
  final String? subtitle;
  final String? value;

  const GroupByOption({
    required this.title,
    this.subtitle,
    required this.value,
  });
}

/// The shared "Group by" radio list used by every filter bottom sheet.
///
/// Renders a heading followed by a divider-separated list of radio options,
/// so grouping looks and behaves the same across the app.
class GroupBySelector extends StatelessWidget {
  /// Sentinel standing in for the `null` ("None") option, since [RadioGroup]
  /// treats a null group value as "nothing selected" and would leave the
  /// "None" row unselected.
  static const String _noneSentinel = '__group_by_none__';

  final List<GroupByOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String heading;

  const GroupBySelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.heading = 'Group by',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    final rows = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, color: dividerColor));
      rows.add(_buildTile(options[i], theme, isDark));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        RadioGroup<String>(
          groupValue: selected ?? _noneSentinel,
          onChanged: (value) =>
              onChanged(value == _noneSentinel ? null : value),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildTile(GroupByOption option, ThemeData theme, bool isDark) {
    return RadioListTile<String>(
      value: option.value ?? _noneSentinel,
      title: Text(
        option.title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: option.subtitle == null
          ? null
          : Text(
              option.subtitle!,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
      activeColor: theme.primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }
}
