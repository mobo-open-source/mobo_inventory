import 'package:flutter/material.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Themed wrapper around `showDatePicker` so every date picker in the app
/// uses the same Mobo colours (primary header, primary selection, primary
/// "today" border).
class MoboDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = primaryColor;

    // showDatePicker asserts firstDate <= initialDate <= lastDate down to the
    // exact time-of-day, so stray hours/minutes (from DateTime.now()) or a
    // stored date that's since fallen before firstDate (e.g. an existing
    // scheduled date reopened on a later day) can trip the assertion and
    // crash. Normalize to date-only and clamp into range to make the picker
    // always openable regardless of what callers pass in.
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    final effectiveFirst = dateOnly(firstDate ?? DateTime(2000));
    final effectiveLast = dateOnly(lastDate ?? DateTime(2100));
    var effectiveInitial = dateOnly(initialDate ?? DateTime.now());
    if (effectiveInitial.isBefore(effectiveFirst)) {
      effectiveInitial = effectiveFirst;
    } else if (effectiveInitial.isAfter(effectiveLast)) {
      effectiveInitial = effectiveLast;
    }

    return showDatePicker(
      context: context,
      initialDate: effectiveInitial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      helpText: helpText,
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: primary,
              onPrimary: Colors.white,
              surface: isDark ? AppTheme.darkSurface : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black,
            ),
            datePickerTheme: DatePickerThemeData(
              // §19 dialog: flat, white / #1E1E1E, radius 20.
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: primary,
              headerForegroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primary;
                return Colors.transparent;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return isDark ? Colors.white : Colors.black;
              }),
              todayBorder: const BorderSide(color: primary, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
