import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/forms/mobo_date_picker.dart';

class SnoozeResult {
  final String predefinedDate;
  final DateTime? customDate;
  SnoozeResult({required this.predefinedDate, this.customDate});
}

class SnoozeBottomSheet extends StatelessWidget {
  const SnoozeBottomSheet({super.key});

  static Future<SnoozeResult?> show(BuildContext context) async {
    return showModalBottomSheet<SnoozeResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SnoozeBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      // The options' ripples paint on the nearest Material; without this one
      // that is the route's, underneath this container's colour, so they
      // were hidden.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          // Scrolls when the options don't fit (a phone in landscape); sized
          // to its content otherwise.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
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
                ),
                const SizedBox(height: 4),
                Text(
                  'Snooze Replenishment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how long to snooze this orderpoint',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                _option(
                  context,
                  label: '1 Day',
                  subtitle: 'Remind me tomorrow',
                  code: 'day',
                ),
                _option(
                  context,
                  label: '1 Week',
                  subtitle: 'Remind me next week',
                  code: 'week',
                ),
                _option(
                  context,
                  label: '1 Month',
                  subtitle: 'Remind me next month',
                  code: 'month',
                ),
                const SizedBox(height: 8),
                _customOption(context, isDark),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String label,
    required String subtitle,
    required String code,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: () =>
          Navigator.of(context).pop(SnoozeResult(predefinedDate: code)),
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.snooze_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 18,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white54 : Colors.black38,
      ),
    );
  }

  Widget _customOption(BuildContext context, bool isDark) {
    return ListTile(
      onTap: () async {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final picked = await MoboDatePicker.show(
          context: context,
          initialDate: tomorrow,
          // Tomorrow at the earliest: Odoo's "Not Snoozed" filter is
          // `snoozed_until <= today`, so a snooze until today would leave
          // the orderpoint on the list and look like it did nothing.
          firstDate: tomorrow,
          lastDate: now.add(const Duration(days: 365 * 2)),
        );
        if (picked != null && context.mounted) {
          Navigator.of(
            context,
          ).pop(SnoozeResult(predefinedDate: 'custom', customDate: picked));
        }
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: StatusColors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.event_outlined,
          color: StatusColors.orange,
          size: 18,
        ),
      ),
      title: Text(
        'Custom...',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        'Pick a specific date',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white54 : Colors.black38,
      ),
    );
  }
}
