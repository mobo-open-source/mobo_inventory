import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A single bordered mini-field rendered in the field row of a [StatusInfoCard].
class StatusInfoField {
  final IconData? icon;
  final String label;
  final String value;

  const StatusInfoField({this.icon, required this.label, required this.value});
}

/// The header "status card" used at the top of detail screens.
///
/// Shows a title with an inline status pill, an optional subtitle, and an
/// optional row of bordered mini-fields underneath. Fields are laid out two
/// per row.
class StatusInfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String statusLabel;
  final Color statusColor;
  final List<StatusInfoField> fields;

  const StatusInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    this.fields = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusColors.buildStatusBadge(
                statusLabel,
                statusColor,
                isDark: isDark,
              ),
            ],
          ),
          ..._buildFieldRows(isDark),
        ],
      ),
    );
  }

  /// Lays the fields out two per row, matching the paired look of the design.
  List<Widget> _buildFieldRows(bool isDark) {
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      final left = fields[i];
      final right = i + 1 < fields.length ? fields[i + 1] : null;
      rows.add(const SizedBox(height: 16));
      rows.add(
        Row(
          children: [
            Expanded(child: _buildField(left, isDark)),
            if (right != null) ...[
              const SizedBox(width: 12),
              Expanded(child: _buildField(right, isDark)),
            ] else
              const Spacer(),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _buildField(StatusInfoField field, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          if (field.icon != null)
            Icon(
              field.icon,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  field.value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
