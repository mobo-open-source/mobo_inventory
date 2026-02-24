import 'package:flutter/material.dart';

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
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SnoozeBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Snooze Replenishment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how long to snooze this orderpoint',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _option(context, label: '1 Day', subtitle: 'Remind me tomorrow', code: 'day'),
            _option(context, label: '1 Week', subtitle: 'Remind me next week', code: 'week'),
            _option(context, label: '1 Month', subtitle: 'Remind me next month', code: 'month'),
            const SizedBox(height: 8),
            _customOption(context, isDark),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, {required String label, required String subtitle, required String code}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: () => Navigator.of(context).pop(SnoozeResult(predefinedDate: code)),
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.snooze_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
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
        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black38),
    );
  }

  Widget _customOption(BuildContext context, bool isDark) {
    return ListTile(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now.add(const Duration(days: 1)),
          firstDate: now,
          lastDate: now.add(const Duration(days: 365 * 2)),
          builder: (ctx, child) {
            return Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: Theme.of(ctx).colorScheme.copyWith(secondary: Theme.of(ctx).primaryColor),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && context.mounted) {
          Navigator.of(context).pop(SnoozeResult(predefinedDate: 'custom', customDate: picked));
        }
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.event_outlined, color: Colors.orange, size: 18),
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
        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black38),
    );
  }
}
