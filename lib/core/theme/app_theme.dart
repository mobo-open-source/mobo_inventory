import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme definition for the application, and the single source of
/// truth for the palette in §1 of the UI style guide.
///
/// Anything colour-, shadow- or radius-shaped belongs here, in [StatusColors],
/// [AppShadows] or [AppRadius] — never as a raw `Colors.*` literal in a widget.
class AppTheme {
  // --- Brand -------------------------------------------------------------
  static const Color primaryColor = Color(0xFFC03355);
  static const Color secondaryColor = Color(0xFFFFFFFF);

  /// Pale primary tint behind tag chips and multi-select chips (§7, §10).
  static const Color primaryTint = Color(0xFFFCE7EE);

  // --- Surfaces ----------------------------------------------------------
  static const Color white = Color(0xFFFFFFFF);

  /// Scaffold background (light theme).
  static const Color scaffoldBackground = Color(0xFFFAFAFA);

  /// Generic light background.
  static const Color background = Color(0xFFF3F3F3);
  static const Color lightGrey = background;

  /// Scaffold background (dark theme).
  static const Color darkScaffold = Color(0xFF181A20);

  /// Card/sheet/dialog surface (dark theme).
  static const Color darkSurface = Color(0xFF1E1E1E);

  /// Popup menu surface (dark theme).
  static const Color darkPopupSurface = Color(0xFF2C2C2E);

  /// Closed text-field fill (light theme) — §6.
  static const Color inputFill = Color(0xFFF2F4F6);

  // --- Text & hairlines --------------------------------------------------
  static const Color dark = Color(0xFF101010);
  static const Color textPrimary = dark;
  static const Color textSecondary = Color(0xFF666666);
  static const Color divider = Color(0xFFE0E0E0);

  /// Reference shadow colour constant — black @ ~10%.
  static const Color shadow = Color(0x1A000000);

  /// Gold used by star-rating controls. Named here rather than reaching for
  /// `Colors.amber` in a widget (§1).
  static const Color ratingStar = Color(0xFFFFC107);

  // --- Semantic ----------------------------------------------------------
  static const Color success = StatusColors.green;
  static const Color warning = StatusColors.orange;
  static const Color error = StatusColors.red;
  static const Color info = StatusColors.blue;

  /// Convenience label helpers so widgets don't re-derive them.
  static Color labelColor(bool isDark) => isDark ? Colors.white : dark;
  static Color secondaryLabelColor(bool isDark) =>
      isDark ? Colors.grey[400]! : Colors.grey[600]!;

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: scaffoldBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: _cardTheme(white),
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    floatingActionButtonTheme: _fabTheme,
    inputDecorationTheme: _inputDecorationTheme,
    popupMenuTheme: _popupMenuTheme(white),
    dialogTheme: _dialogTheme(white),
    bottomSheetTheme: _bottomSheetTheme(Colors.grey[50]!),
    dividerTheme: const DividerThemeData(color: divider, thickness: 1),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: darkScaffold,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: _cardTheme(Colors.grey[850]!),
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    floatingActionButtonTheme: _fabTheme,
    inputDecorationTheme: _inputDecorationTheme,
    popupMenuTheme: _popupMenuTheme(darkPopupSurface),
    dialogTheme: _dialogTheme(darkSurface),
    bottomSheetTheme: _bottomSheetTheme(darkSurface),
    dividerTheme: DividerThemeData(color: Colors.grey[800], thickness: 1),
  );

  // --- Shared component themes (§3: flat — depth only from BoxShadow) ----

  static CardThemeData _cardTheme(Color color) => CardThemeData(
    color: color,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );

  static const FloatingActionButtonThemeData _fabTheme =
      FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      );

  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      );

  static PopupMenuThemeData _popupMenuTheme(Color color) => PopupMenuThemeData(
    color: color,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
  );

  static DialogThemeData _dialogTheme(Color color) => DialogThemeData(
    backgroundColor: color,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
  );

  static BottomSheetThemeData _bottomSheetTheme(Color color) =>
      BottomSheetThemeData(
        backgroundColor: color,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      );

  // --- Decorations -------------------------------------------------------

  /// The canonical flat card from §8 — flat fill, hairline border,
  /// [AppShadows.cardShadow].
  static BoxDecoration cardDecoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : white,
    borderRadius: BorderRadius.circular(AppRadius.md),
    border: Border.all(
      color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
      width: 0.5,
    ),
    boxShadow: AppShadows.card,
  );

  /// Larger dashboard/section container — §8's "panel" variant.
  static BoxDecoration panelDecoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : white,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: AppShadows.panel(isDark),
  );
}

/// §4 — the radius scale. Default to [md] when unsure.
class AppRadius {
  const AppRadius._();

  /// Small chip corner, tiny inner accents.
  static const double xs = 4;

  /// Compact/status dropdown, icon-button container.
  static const double sm = 5;

  /// Small tab/segment chip.
  static const double chip = 6;

  /// Dropdown/filter control, popup menus, inner input border.
  static const double control = 8;

  /// Segmented view-selector, quantity/numeric field variant.
  static const double segment = 10;

  /// Default — cards, list tiles, buttons, text fields, tag chips.
  static const double md = 12;

  /// Kanban column, bottom sheet (top corners), panel/section container,
  /// compact confirm/delete dialogs.
  static const double lg = 16;

  /// Canonical status badge.
  static const double badge = 18;

  /// Pill buttons/chips, dialogs, pagination counter, active-filters pill.
  static const double pill = 20;

  /// Tall/full bottom-sheet variant (rare).
  static const double sheet = 28;
}

/// §3 — depth comes from these explicit shadows, never from Material
/// `elevation`.
class AppShadows {
  const AppShadows._();

  /// Standard "flat card" shadow — list items, list-style cards, form cards.
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0D000000), // black @ 5%
    offset: Offset(0, 6),
    blurRadius: 16,
    spreadRadius: 2,
  );

  /// "Panel" shadow — bigger surfaces like chart containers, dashboard
  /// sections.
  static BoxShadow panelShadow(bool isDark) => BoxShadow(
    color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  /// Soft shadow for pill-shaped search bars only.
  static const BoxShadow searchShadow = BoxShadow(
    color: Color(0x0A000000), // black @ 4%
    offset: Offset(3, 11),
    blurRadius: 8.5,
    spreadRadius: -3,
  );

  static const List<BoxShadow> card = <BoxShadow>[cardShadow];
  static const List<BoxShadow> search = <BoxShadow>[searchShadow];
  static List<BoxShadow> panel(bool isDark) => <BoxShadow>[
    panelShadow(isDark),
  ];
}

/// §1/§10 — the semantic status map, and the one badge that renders it.
///
/// Every status/stage indicator resolves its colour through [forState] rather
/// than reaching for `Colors.green`/`Colors.orange` and drifting per screen.
class StatusColors {
  const StatusColors._();

  /// approved, done, posted, won, paid, planned
  static const Color green = Color(0xFF00A63E);

  /// sent, qualified, in-progress/proposal
  static const Color blue = Color(0xFF3B82F6);

  /// draft
  static const Color orange = Color(0xFFF97316);

  /// cancelled, lost
  static const Color red = Color(0xFFEF4444);

  /// locked/done (secondary "complete" state)
  static const Color teal = Color(0xFF14B8A6);

  /// unknown/default fallback
  static const Color grey = Color(0xFF6B7280);

  // --- Tinted icon/background pairs (§16) --------------------------------
  static const Color infoIcon = Color(0xFF60A5FA);
  static const Color successIcon = Color(0xFF4ADE80);
  static const Color warningIcon = Color(0xFFFBBF24);
  static const Color errorIcon = Color(0xFFF87171);

  static Color iconBackground(Color color) => color.withValues(alpha: 0.12);

  static Color backgroundLight(Color color) => color.withValues(alpha: 0.12);
  static Color backgroundDark(Color color) => color.withValues(alpha: 0.2);

  /// Resolves an Odoo `state` value (stock.picking, stock.move, mrp.production,
  /// stock.quant …) to its semantic colour.
  ///
  /// Inventory states the guide doesn't name map to their nearest meaning:
  /// "waiting"/"confirmed" are in progress (blue), and "assigned" (Ready),
  /// "to_close" and "locked" are positive/complete states, so they share
  /// green with "done".
  static Color forState(String? state) {
    switch (state?.toLowerCase().trim()) {
      case 'done':
      case 'posted':
      case 'paid':
      case 'approved':
      case 'planned':
      case 'won':
      case 'assigned':
      case 'ready':
      case 'to_close':
      case 'locked':
        return green;
      case 'draft':
        return orange;
      case 'cancel':
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'lost':
        return red;
      case 'waiting':
      case 'confirmed':
      case 'sent':
      case 'progress':
      case 'in_progress':
      case 'partially_available':
        return blue;
      default:
        return grey;
    }
  }

  /// §10 — the canonical status badge. No border; tint comes from [color].
  static Widget buildStatusBadge(
    String label,
    Color color, {
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
