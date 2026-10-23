import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../design/mobo_tokens.dart';
import '../mobo/mobo_field_shell.dart';
import '../mobo/mobo_overlay_panel.dart';

/// The create/edit form dropdown, drawn by the Mobo design system.
///
/// Keeps the `List<DropdownMenuItem<T>>` API the forms already pass, so no
/// call site changes: each item's own `child` is rendered in the panel and in
/// the closed field, wrapped in the system's text style.
///
/// [isDark] and [showBorder] are accepted but ignored — the shell resolves
/// light and dark from `Theme.of(context).brightness`, and its border belongs
/// to the system rather than to a call site.
class CustomGenericDropdownField<T> extends StatefulWidget {
  final T? value;
  final String labelText;
  final String? hintText;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool isDark;
  final List<DropdownMenuItem<T>> items;
  final bool showBorder;

  /// Search box at the top of the panel.
  ///
  /// Left null it turns itself on once the list passes
  /// [searchThreshold] — a search box over four options is clutter, and
  /// scrolling a list of forty to find one is worse. Pass true or false to
  /// decide at the call site.
  final bool? searchable;

  /// What to match a typed query against.
  ///
  /// Only needed where an item's `child` is not a [Text]; otherwise the text
  /// is read straight off it.
  final String Function(T value)? labelOf;

  final String searchHintText;

  /// Marks the label with a red asterisk.
  ///
  /// Explicit rather than inferred from [validator]: these forms give optional
  /// fields validators too — an email format check, or a `(v) => null`
  /// placeholder — so a validator says nothing about whether a value is needed.
  final bool isRequired;

  /// Shows a clear button in place of the chevron once a value is chosen.
  /// False for a field the record cannot be saved without.
  final bool allowClear;

  /// Item count at or above which [searchable] defaults to on.
  static const int searchThreshold = 8;

  const CustomGenericDropdownField({
    super.key,
    required this.value,
    required this.labelText,
    required this.onChanged,
    this.validator,
    required this.items,
    this.hintText,
    this.isDark = false,
    this.showBorder = false,
    this.searchable,
    this.labelOf,
    this.searchHintText = 'Search...',
    this.isRequired = false,
    this.allowClear = true,
  });

  @override
  State<CustomGenericDropdownField<T>> createState() =>
      _CustomGenericDropdownFieldState<T>();
}

class _CustomGenericDropdownFieldState<T>
    extends State<CustomGenericDropdownField<T>>
    with MoboOverlayPanelMixin<CustomGenericDropdownField<T>> {
  late final TextEditingController _searchController = TextEditingController(
    text: _selectedLabel,
  );
  late final FocusNode _searchFocusNode = FocusNode()
    ..addListener(_onSearchFocusChanged);

  String _query = '';

  /// The label of the option the user last picked here.
  ///
  /// The field's text cannot be derived from [widget.items] alone: options
  /// often arrive from a provider and are replaced wholesale, so the chosen
  /// value can be absent from the list by the time the field redraws.
  String? _pickedLabel;

  /// What the closed field should show.
  String get _selectedLabel {
    if (widget.value == null) return '';
    final selected = _selectedItem;
    if (selected != null) return _labelOf(selected) ?? _pickedLabel ?? '';
    return _pickedLabel ?? '';
  }

  bool get _enabled => widget.onChanged != null;

  DropdownMenuItem<T>? get _selectedItem {
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  /// Null where the item carries no readable text, which is the signal that a
  /// query cannot judge it either way.
  String? _labelOf(DropdownMenuItem<T> item) {
    final value = item.value;
    if (widget.labelOf != null && value != null) return widget.labelOf!(value);
    final child = item.child;
    if (child is Text) return child.data;
    return null;
  }

  bool get _searchable =>
      widget.searchable ??
      // Auto only when every item can actually be matched, so turning it on
      // never produces a box that silently fails to filter half the list.
      (widget.items.length >= CustomGenericDropdownField.searchThreshold &&
          widget.items.every((item) => _labelOf(item) != null));

  List<DropdownMenuItem<T>> get _visibleItems {
    final query = _query.toLowerCase();

    final matches = query.isEmpty
        ? [...widget.items]
        : widget.items.where((item) {
            final label = _labelOf(item);
            // An item with no readable text is kept rather than hidden: better
            // a stray row than an option the user can no longer reach.
            if (label == null) return true;
            return label.toLowerCase().contains(query);
          }).toList();

    // The current value goes to the top, so it is visible the moment the panel
    // opens instead of somewhere down a list the user has to scroll to reach —
    // and so clearing or re-confirming it never takes a search.
    final selectedIndex = matches.indexWhere((i) => i.value == widget.value);
    if (selectedIndex > 0) {
      final selected = matches.removeAt(selectedIndex);
      matches.insert(0, selected);
    }

    return matches;
  }

  @override
  void didUpdateWidget(covariant CustomGenericDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent owns the value, so a change made elsewhere has to reach the
    // field's text — unless the user is mid-query, which must not be clobbered.
    if (oldWidget.value != widget.value && !_searchFocusNode.hasFocus) {
      // A value set from elsewhere is not the one picked here, so the
      // remembered label no longer describes it.
      final selected = _selectedItem;
      if (selected != null) _pickedLabel = _labelOf(selected);
      _searchController.text = _selectedLabel;
    }
    // Options often arrive from a provider while the panel is open.
    if (oldWidget.items != widget.items) refreshPanel();
  }

  @override
  void dispose() {
    disposePanel();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      if (!isPanelOpen) _open();
      // Select-all, so the first keystroke replaces the current value rather
      // than appending to it.
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    } else {
      // A half-typed query must not linger looking like the chosen value.
      _searchController.text = _selectedLabel;
      _query = '';
      refreshPanel();
    }
    if (mounted) setState(() {});
  }

  void _open() {
    // A stale query would filter the list down before the user has typed.
    _query = '';
    openPanel(
      searchable: _searchable,
      builder: _buildPanel,
      onBarrierTap: _searchable ? _closeAndUnfocus : null,
    );
  }

  void _toggle() {
    if (!_enabled) return;
    if (isPanelOpen) {
      _closeAndUnfocus();
    } else if (_searchable) {
      _searchFocusNode.requestFocus();
    } else {
      _open();
    }
  }

  /// Unfocuses the search box before closing the panel, so a tap-outside
  /// dismiss leaves the field in the same state as picking an item or
  /// tapping the chevron does. Left out, the field stays focused with the
  /// panel gone — tapping it again fires no focus change, so the panel never
  /// reopens, and typing updates the query with no panel left to show it in.
  void _closeAndUnfocus() {
    _searchFocusNode.unfocus();
    closePanel();
  }

  void _onQueryChanged(String value) {
    _query = value;
    // The panel is a sibling in the Overlay, so it needs telling separately.
    setState(() {});
    refreshPanel();
  }

  void _pick(DropdownMenuItem<T> item) {
    // Recorded before unfocusing: `unfocus()` runs the focus listener
    // synchronously, and that restores the field's text from the current
    // value — which the parent has not been told about yet.
    _pickedLabel = _labelOf(item);
    _query = '';
    _searchController.text = _pickedLabel ?? '';
    _searchFocusNode.unfocus();
    closePanel();
    widget.onChanged?.call(item.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mobo;
    final selected = _selectedItem;

    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        // Keeps the enclosing Form in step with the value the parent owns.
        if (field.value != widget.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) field.didChange(widget.value);
          });
        }

        return CompositedTransformTarget(
          link: layerLink,
          child: MoboFieldShell(
            label: widget.labelText,
            isRequired: widget.isRequired,
            errorText: field.errorText,
            enabled: _enabled,
            isFocused: isPanelOpen,
            // A searchable field is a text input: the shell must not eat the
            // tap that places the caret.
            onTap: _searchable ? null : _toggle,
            child: Row(
              children: [
                Expanded(
                  child: _searchable
                      ? _buildSearchInput(colors)
                      : selected == null
                      ? Text(
                          widget.hintText ?? 'Select',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoboType.hint(
                            colors.isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                            size: 16,
                            italic: true,
                          ),
                        )
                      : DefaultTextStyle(
                          // §7 selected item: w600 at 16.
                          style: MoboType.fieldValue(
                            colors.textPrimary,
                          ).copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: selected.child,
                        ),
                ),
                _buildTrailing(colors, selected),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clear() {
    _pickedLabel = null;
    _query = '';
    _searchController.clear();
    _searchFocusNode.unfocus();
    closePanel();
    widget.onChanged?.call(null);
  }

  /// Clear when there is something to clear, otherwise the chevron.
  ///
  /// The chevron gets its own gesture target because the field itself is a
  /// text input once searchable — a tap there places the caret rather than
  /// opening the list.
  Widget _buildTrailing(MoboColors colors, DropdownMenuItem<T>? selected) {
    if (widget.allowClear && selected != null && _enabled) {
      // A 36pt target: the bare glyph is half what a fingertip needs, and a
      // near-miss opens the list instead of clearing.
      return SizedBox(
        width: MoboSpacing.minTouchTarget,
        height: MoboSpacing.minTouchTarget,
        child: InkWell(
          onTap: _clear,
          borderRadius: BorderRadius.circular(MoboRadius.pill),
          child: Icon(Icons.close, size: 18, color: colors.textSecondary),
        ),
      );
    }

    return GestureDetector(
      onTap: _enabled ? _toggle : null,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        isPanelOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
        color: colors.textSecondary,
      ),
    );
  }

  /// The closed field, doubling as the search box.
  ///
  /// There is no second search box inside the panel: two inputs for one list
  /// is one too many, and the field is already where the user is looking.
  Widget _buildSearchInput(MoboColors colors) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      enabled: _enabled,
      onChanged: _onQueryChanged,
      style: MoboType.fieldValue(colors.textPrimary).copyWith(fontSize: 16),
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        hintText: widget.hintText ?? 'Select',
        hintStyle: MoboType.hint(
          colors.isDark ? Colors.grey[400]! : Colors.grey[600]!,
          size: 16,
          italic: true,
        ),
        // Every state, or one falls back to the theme outline and draws a
        // second border inside the shell's own.
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
    );
  }

  Widget _buildPanel(BuildContext context, double maxHeight) {
    final colors = context.mobo;

    // §7 popup: radius 16, elevation 4.
    return Material(
      elevation: 4,
      color: colors.popupSurface,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.divider),
        ),
        child: _buildList(colors),
      ),
    );
  }

  Widget _buildList(MoboColors colors) {
    final items = _visibleItems;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        // heightFactor, or the panel stretches to its maximum around a single
        // line and leaves a tall empty box under it.
        child: Center(
          heightFactor: 1,
          child: Text(
            // The two empty states are not the same thing, and saying "No
            // options" to someone mid-search reads as a broken list.
            _query.isEmpty ? 'No options' : 'No matches',
            style: MoboType.body(colors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.value == widget.value;

        return InkWell(
          // Through _pick, not straight to onChanged: picking has to update
          // the field's own text and drop the query too, and calling the
          // callback directly skipped both — so the chosen option never
          // appeared in the closed field.
          onTap: () => _pick(item),
          child: Container(
            color: isSelected ? colors.primaryTint : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style:
                        MoboType.fieldValue(
                          isSelected ? colors.primary : colors.textPrimary,
                        ).copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: item.child,
                  ),
                ),
                // Only the selected row carries a mark.
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The string-valued form dropdown — [CustomGenericDropdownField] fixed to
/// `String`, which is what most of the forms use.
class CustomDropdownField extends StatelessWidget {
  final String? value;
  final String labelText;
  final String? hintText;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final bool isDark;
  final List<DropdownMenuItem<String>> items;
  final bool showBorder;
  final bool? searchable;
  final String searchHintText;
  final bool isRequired;
  final bool allowClear;

  const CustomDropdownField({
    required this.value,
    required this.labelText,
    required this.onChanged,
    this.validator,
    required this.items,
    this.hintText,
    this.isDark = false,
    this.showBorder = false,
    this.searchable,
    this.searchHintText = 'Search...',
    this.isRequired = false,
    this.allowClear = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomGenericDropdownField<String>(
      value: value,
      labelText: labelText,
      hintText: hintText,
      onChanged: onChanged,
      validator: validator,
      items: items,
      searchable: searchable,
      searchHintText: searchHintText,
      isRequired: isRequired,
      allowClear: allowClear,
    );
  }
}
