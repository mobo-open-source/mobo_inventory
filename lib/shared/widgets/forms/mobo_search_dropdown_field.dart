import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Labeled single-select searchable dropdown matching the mobo/CRM design system.
///
/// Uses [DropdownSearch] for an inline popup with search:
/// - Label + optional red [isRequired] star
/// - Grey fill, no border when unfocused, red border when open/focused
/// - Popup: search box + items with check-mark for selected item
/// - Dark/light mode via [isDark]
/// - Optional [isLoading] spinner inside the field (e.g., while options load)
class MoboSearchDropdownField<T> extends StatelessWidget {
  final String label;
  final bool isRequired;
  final T? selectedItem;
  final List<T> items;
  final String Function(T) displayText;
  final ValueChanged<T?> onChanged;
  final String hintText;
  final bool isDark;
  final bool isLoading;
  final String searchHint;
  final bool showSearch;
  final bool Function(T, T)? compareFn;

  const MoboSearchDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.displayText,
    required this.onChanged,
    required this.isDark,
    this.selectedItem,
    this.isRequired = false,
    this.hintText = 'Select...',
    this.isLoading = false,
    this.searchHint = 'Search...',
    this.showSearch = true,
    this.compareFn,
  });

  /// [items] with the current selection moved to the top, so it is visible
  /// the moment the popup opens.
  List<T> get _orderedItems {
    final selected = selectedItem;
    if (selected == null) return items;
    bool same(T a) => compareFn?.call(a, selected) ?? a == selected;
    final index = items.indexWhere(same);
    if (index <= 0) return items;
    return [items[index], ...items.where((e) => !same(e))];
  }

  @override
  Widget build(BuildContext context) {
    final items = _orderedItems;
    final bgColor = isDark ? Colors.grey[850]! : AppTheme.inputFill;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final popupBg = isDark ? AppTheme.darkPopupSurface : Colors.white;
    final searchFill = isDark ? Colors.grey[850]! : const Color(0xFFF3F4F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        DropdownSearch<T>(
          items: items,
          selectedItem: selectedItem,
          onChanged: onChanged,
          itemAsString: displayText,
          compareFn: compareFn,

          // ── Field display ──────────────────────────────────────────────────
          dropdownBuilder: (context, selected) {
            if (isLoading) {
              return Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading...',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              );
            }
            return Text(
              selected != null ? displayText(selected) : hintText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // §7 selected item: w600 at 16; the placeholder stays w400.
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight:
                    selected == null ? FontWeight.w400 : FontWeight.w600,
                color: selected == null ? hintColor : textColor,
                fontStyle:
                    selected == null ? FontStyle.italic : FontStyle.normal,
              ),
            );
          },

          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
          ),

          // ── Field decoration ───────────────────────────────────────────────
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          // ── Popup ──────────────────────────────────────────────────────────
          popupProps: PopupProps.menu(
            containerBuilder: (ctx, popupWidget) =>
                TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -8 * (1 - value)),
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * value,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
              ),
              child: popupWidget,
            ),
            showSearchBox: showSearch,
            searchFieldProps: TextFieldProps(
              style: GoogleFonts.manrope(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  color: hintColor,
                ),
                filled: true,
                fillColor: searchFill,
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: iconColor,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
            menuProps: MenuProps(
              backgroundColor: popupBg,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Dynamic height: search box ~68px + 8px pad + 52px per item.
            // When empty, reserve 160px so "No data found" has room to show.
            constraints: BoxConstraints(
              maxHeight: items.isEmpty
                  ? (showSearch ? 184.0 : 96.0)
                  : ((showSearch ? 68.0 : 8.0) +
                          8.0 +
                          items.length * 52.0)
                      .clamp(72.0, 320.0),
            ),
            emptyBuilder: (context, searchEntry) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Text(
                  searchEntry.isNotEmpty
                      ? 'No results for "$searchEntry"'
                      : 'No data found',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ),
            ),
            itemBuilder: (context, item, isSelected) {
              final index = items.indexOf(item);
              final delay = (index < 0 ? 0 : index) * 30;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 160 + delay),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Container(
                  color: isSelected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.grey[100])
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayText(item),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? primaryColor
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLabel() {
    return Text.rich(
      TextSpan(
        text: label,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
        children: isRequired
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: StatusColors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}
