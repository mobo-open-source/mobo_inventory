import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Labeled single-select searchable dropdown, built on [TypeAheadField]
/// (flutter_typeahead) instead of [dropdown_search].
///
/// Same field-level look as [MoboSearchDropdownField] (grey fill, no border
/// when unfocused, primary-coloured border when focused) so it drops in
/// wherever that widget is used, but the suggestions are searched inline in
/// the field itself rather than in a separate popup search box.
class MoboTypeaheadDropdownField<T> extends StatefulWidget {
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
  final bool Function(T, T)? compareFn;

  const MoboTypeaheadDropdownField({
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
    this.compareFn,
  });

  @override
  State<MoboTypeaheadDropdownField<T>> createState() =>
      _MoboTypeaheadDropdownFieldState<T>();
}

class _MoboTypeaheadDropdownFieldState<T>
    extends State<MoboTypeaheadDropdownField<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Whether the user has actually typed since the field gained focus, as
  /// opposed to just tapping in (which leaves the current selection's label
  /// showing, selected, ready to be overwritten). Suggestions are filtered
  /// by the field text only once this is true, so tapping in always opens
  /// on the full list rather than one immediately narrowed to whatever was
  /// already selected.
  bool _hasTypedSinceFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _labelFor(widget.selectedItem));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(MoboTypeaheadDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field text in sync when the selection changes from outside
    // (e.g. picking a Transfer Type auto-fills the location fields) without
    // clobbering whatever the user is currently typing.
    if (!_focusNode.hasFocus && !_isSame(oldWidget.selectedItem, widget.selectedItem)) {
      _controller.text = _labelFor(widget.selectedItem);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _isSame(T? a, T? b) {
    if (widget.compareFn != null && a != null && b != null) {
      return widget.compareFn!(a, b);
    }
    return a == b;
  }

  String _labelFor(T? item) => item == null ? '' : widget.displayText(item);

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      // Entering edit mode: keep the current selection visible rather than
      // blanking it, and select it all so the first keystroke replaces it.
      _hasTypedSinceFocus = false;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      // Leaving without picking anything: restore the current selection.
      final expected = _labelFor(widget.selectedItem);
      if (_controller.text != expected) {
        _controller.text = expected;
      }
    }
  }

  List<T> _suggestionsFor(String search) {
    // Until the user actually types, the field is just displaying the
    // current selection — search against '' so the full list shows instead
    // of narrowing to whatever's already selected.
    final effective = _hasTypedSinceFocus ? search : '';
    final query = effective.trim().toLowerCase();
    final matches = query.isEmpty
        ? [...widget.items]
        : widget.items
              .where(
                (item) =>
                    widget.displayText(item).toLowerCase().contains(query),
              )
              .toList();

    // The current selection goes to the top, so it is visible the moment the
    // list opens instead of somewhere the user has to scroll to reach.
    final selected = widget.selectedItem;
    if (selected != null) {
      final index = matches.indexWhere((item) => _isSame(item, selected));
      if (index > 0) matches.insert(0, matches.removeAt(index));
    }
    return matches;
  }

  void _clear() {
    // Deliberately doesn't unfocus: widget.onChanged(null) only marks the
    // parent dirty, it doesn't update widget.selectedItem in this frame, so
    // unfocusing immediately here would hit the blur-restore branch above
    // while it's still reading the *old* selection and undo the clear.
    // Staying focused also means the now-empty field immediately shows the
    // full list to pick a replacement from.
    widget.onChanged(null);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? Colors.grey[850]! : AppTheme.inputFill;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final hintColor = widget.isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final iconColor = widget.isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final popupBg =
        widget.isDark ? AppTheme.darkPopupSurface : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        TypeAheadField<T>(
          controller: _controller,
          focusNode: _focusNode,
          suggestionsCallback: _suggestionsFor,
          onSelected: (item) {
            widget.onChanged(item);
            setState(() => _controller.text = widget.displayText(item));
            _focusNode.unfocus();
          },
          constraints: const BoxConstraints(maxHeight: 320),
          builder: (context, controller, focusNode) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !widget.isLoading,
                  onChanged: (_) => _hasTypedSinceFocus = true,
                  // §7 selected item: w600 at 16.
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: bgColor,
                    hintText: widget.isLoading ? 'Loading...' : widget.hintText,
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                    prefixIcon: widget.isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            ),
                          )
                        : null,
                    suffixIcon: (!widget.isLoading && value.text.isNotEmpty)
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: iconColor),
                            tooltip: 'Clear',
                            onPressed: _clear,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              },
            );
          },
          decorationBuilder: (context, child) {
            return Material(
              type: MaterialType.card,
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              color: popupBg,
              child: child,
            );
          },
          itemBuilder: (context, item) {
            final isSelected = _isSame(item, widget.selectedItem);
            return Container(
              color: isSelected
                  ? (widget.isDark
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
                      widget.displayText(item),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? primaryColor
                            : (widget.isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded, color: primaryColor, size: 18),
                ],
              ),
            );
          },
          emptyBuilder: (context) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Text(
                'No results for "${_controller.text}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel() {
    return Text.rich(
      TextSpan(
        text: widget.label,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: widget.isDark ? Colors.white : AppTheme.textPrimary,
        ),
        children: widget.isRequired
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
