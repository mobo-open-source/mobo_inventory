import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// The Mobo design tokens.
///
/// Every widget in `shared/widgets/mobo/` reads its colours, radii, shadows,
/// type and spacing from here, so none of them repeats a raw hex literal and
/// a change lands everywhere at once.
///
/// Colours resolve per theme through [MoboColors.of], and the brand colour
/// always comes from `Theme.of(context).primaryColor` rather than being
/// hard-coded, so an app that re-brands gets it for free.
///
/// The values themselves come from the UI style guide via `AppTheme`,
/// `StatusColors`, `AppRadius` and `AppShadows` in
/// `lib/core/theme/app_theme.dart` — this file only names them for the
/// `shared/widgets/mobo/` components.

/// Resolved colour set for the current theme.
///
/// Read it with `context.mobo` rather than constructing one.
class MoboColors {
  const MoboColors._({
    required this.primary,
    required this.primaryTint,
    required this.scaffold,
    required this.surface,
    required this.popupSurface,
    required this.inputFill,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
    required this.searchIcon,
    required this.isDark,
  });

  /// Brand: selected states, focus borders, primary buttons.
  final Color primary;

  /// Selected rows, selected chips, tinted cards.
  final Color primaryTint;

  /// Page background.
  final Color scaffold;

  /// Cards, search field, panels.
  final Color surface;

  /// Overlay dropdown panels, which sit lifted off the page.
  final Color popupSurface;

  /// Closed field fill.
  final Color inputFill;

  /// Hairlines.
  final Color divider;

  /// Titles and values.
  final Color textPrimary;

  /// Labels, meta, hints.
  final Color textSecondary;

  /// Invalid borders and messages.
  final Color error;

  /// The search field's leading glyph, which sits lighter than
  /// [textSecondary] so it reads as decoration rather than as content.
  final Color searchIcon;

  final bool isDark;

  static MoboColors of(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return isDark
        ? MoboColors._(
            primary: primary,
            primaryTint: primary.withValues(alpha: 0.18),
            scaffold: AppTheme.darkScaffold,
            surface: Colors.grey[850]!,
            popupSurface: AppTheme.darkPopupSurface,
            inputFill: Colors.grey[850]!,
            divider: Colors.grey[800]!,
            textPrimary: Colors.white,
            textSecondary: Colors.grey[400]!,
            error: MoboStatusColors.red,
            searchIcon: Colors.white.withValues(alpha: 0.7),
            isDark: true,
          )
        : MoboColors._(
            primary: primary,
            primaryTint: AppTheme.primaryTint,
            scaffold: AppTheme.scaffoldBackground,
            surface: AppTheme.white,
            popupSurface: AppTheme.white,
            inputFill: AppTheme.inputFill,
            divider: AppTheme.divider,
            textPrimary: AppTheme.textPrimary,
            textSecondary: AppTheme.textSecondary,
            error: MoboStatusColors.red,
            searchIcon: const Color(0xFF99A1AF),
            isDark: false,
          );
  }
}

extension MoboColorsContext on BuildContext {
  /// The resolved Mobo palette for this context's theme.
  MoboColors get mobo => MoboColors.of(this);
}

/// Semantic status colours — one per stage, with [grey] as the fallback for
/// a status this app does not recognise.
abstract final class MoboStatusColors {
  static const Color green = StatusColors.green;
  static const Color blue = StatusColors.blue;
  static const Color orange = StatusColors.orange;
  static const Color red = StatusColors.red;
  static const Color teal = StatusColors.teal;
  static const Color grey = StatusColors.grey;
}

abstract final class MoboRadius {
  static const double button = AppRadius.md;
  static const double card = AppRadius.md;

  /// Inputs, overlay panels and fields all share one radius.
  static const double field = AppRadius.md;
  static const double chip = AppRadius.pill;
  static const double pill = 999;
  static const double sheetTop = AppRadius.lg;
  static const double checkbox = AppRadius.xs;
}

/// Depth comes from these alone — every Material in the system stays at
/// `elevation: 0`.
abstract final class MoboShadows {
  /// List items and form cards.
  static const List<BoxShadow> card = AppShadows.card;

  /// Kept as an alias of [card] — the guide has one card shadow (§3).
  static const List<BoxShadow> soft = AppShadows.card;

  /// Pill and rounded search bars only.
  static const List<BoxShadow> search = AppShadows.search;
}

/// Manrope throughout. Each getter takes its colour explicitly so a caller
/// never has to remember which token a given role uses.
abstract final class MoboType {
  static TextStyle title(Color color) =>
      GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w600, color: color);

  static TextStyle h3(Color color) =>
      GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: color);

  static TextStyle body(Color color) =>
      GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w400, color: color);

  static TextStyle label(Color color) =>
      GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w400, color: color);

  static TextStyle fieldValue(Color color) =>
      GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: color);

  /// Pass [italic] for a text-field placeholder (§6); search boxes keep the
  /// upright hint.
  static TextStyle hint(Color color, {double size = 14, bool italic = false}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color,
      );

  static TextStyle chip(Color color) =>
      GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: color);

  static TextStyle meta(Color color) =>
      GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: color);

  static TextStyle badge(Color color, {FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.manrope(fontSize: 11, fontWeight: weight, color: color);

  /// Button labels. The colour comes from the button's own foreground, so this
  /// deliberately sets none — passing one here would fight the disabled state.
  static TextStyle button() =>
      GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold);
}

abstract final class MoboSpacing {
  static const double page = 20;

  /// Between list cards.
  static const double listGap = 10;

  /// Between form fields.
  static const double fieldGap = 16;

  static const double fieldMinHeight = 48;
  static const double iconButton = 48;

  /// Every button in the app is this tall, so a Cancel/Save pair sits level.
  static const double buttonHeight = 48;

  /// No tap target in the system goes below this.
  static const double minTouchTarget = 36;
}
