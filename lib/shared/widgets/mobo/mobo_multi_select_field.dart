import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../design/mobo_tokens.dart';
import 'mobo_field_shell.dart';
import 'mobo_overlay_panel.dart';

/// The Mobo multi-select field, for many2many values such as taxes or tags.
///
/// Closed, the field shows the selection as removable chips — the first
/// [maxVisibleChips], then a "+N more" chip. Tapping it opens a panel under
/// the field with a title, a search box, a "Done" link and one checkbox row
/// per option. Ticks apply straight away (the chips update behind the
/// panel); "Done" or a tap outside closes it.
class MoboMultiSelectField<T> extends StatefulWidget {
  const MoboMultiSelectField({
    super.key,
    required this.label,
    required this.items,
    required this.displayText,
    required this.onChanged,
    this.selectedItems = const [],
    this.panelTitle,
    this.hintText = 'Select...',
    this.searchHintText = 'Search...',
    this.isRequired = false,
    this.isLoading = false,
    this.enabled = true,
    this.maxVisibleChips = 2,
    this.compareFn,
    this.validator,
  });

  final String label;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) displayText;
  final ValueChanged<List<T>> onChanged;

  /// Heading inside the panel; defaults to "Select <label>".
  final String? panelTitle;
  final String hintText;
  final String searchHintText;
  final bool isRequired;
  final bool isLoading;
  final bool enabled;
  final int maxVisibleChips;
  final bool Function(T, T)? compareFn;
  final String? Function(List<T>)? validator;

  @override
  State<MoboMultiSelectField<T>> createState() =>
      _MoboMultiSelectFieldState<T>();
}

class _MoboMultiSelectFieldState<T> extends State<MoboMultiSelectField<T>>
    with MoboOverlayPanelMixin<MoboMultiSelectField<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Kept locally so ticks show immediately, before the parent rebuilds this
  // widget with the new selection.
  late List<T> _selected = List<T>.from(widget.selectedItems);

  /// The selection when the panel opened. Selected options are listed first
  /// by this snapshot rather than the live selection, so a row does not jump
  /// to the top from under the finger the moment it is ticked.
  List<T> _pinned = const [];

  bool get _enabled => widget.enabled && !widget.isLoading;

  @override
  void didUpdateWidget(covariant MoboMultiSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameList(oldWidget.selectedItems, widget.selectedItems)) {
      _selected = List<T>.from(widget.selectedItems);
    }
    // Options often arrive from a provider while the panel is open.
    if (oldWidget.items != widget.items) refreshPanel();
  }

  @override
  void dispose() {
    disposePanel();
    _searchController.dispose();
    super.dispose();
  }

  bool _same(T a, T b) => widget.compareFn?.call(a, b) ?? a == b;

  bool _sameList(List<T> a, List<T> b) =>
      a.length == b.length && a.every((x) => b.any((y) => _same(x, y)));

  bool _isSelected(T item) => _selected.any((e) => _same(e, item));

  List<T> get _visibleItems {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.items
        : widget.items
              .where(
                (item) =>
                    widget.displayText(item).toLowerCase().contains(query),
              )
              .toList();
    bool pinned(T item) => _pinned.any((e) => _same(e, item));
    return [...matches.where(pinned), ...matches.where((e) => !pinned(e))];
  }

  void _setSelected(List<T> next) {
    setState(() => _selected = next);
    widget.onChanged(List<T>.from(next));
    refreshPanel();
  }

  void _toggle(T item) {
    _setSelected(
      _isSelected(item)
          ? _selected.where((e) => !_same(e, item)).toList()
          : [..._selected, item],
    );
  }

  void _open() {
    if (!_enabled || isPanelOpen) return;
    _query = '';
    _searchController.clear();
    _pinned = List<T>.from(_selected);
    openPanel(searchable: true, builder: _buildPanel, onBarrierTap: _close);
  }

  /// Unfocuses the panel's search box as well, so no keyboard is left up
  /// for a panel that is gone.
  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    closePanel();
  }

  void _onQueryChanged(String value) {
    _query = value;
    refreshPanel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mobo;

    return FormField<List<T>>(
      initialValue: _selected,
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(_selected),
      builder: (field) => CompositedTransformTarget(
        link: layerLink,
        child: MoboFieldShell(
          label: widget.label,
          isRequired: widget.isRequired,
          errorText: field.errorText,
          enabled: _enabled,
          isFocused: isPanelOpen,
          // §7 — unlike a single select, the multi-select keeps a visible
          // hairline at rest.
          idleBorderColor: colors.isDark ? Colors.grey[700] : Colors.grey[300],
          onTap: () => isPanelOpen ? _close() : _open(),
          child: Row(
            children: [
              Expanded(child: _buildValue(colors)),
              const SizedBox(width: 8),
              Icon(
                isPanelOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValue(MoboColors colors) {
    if (widget.isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text('Loading...', style: MoboType.hint(colors.textSecondary)),
        ],
      );
    }
    if (_selected.isEmpty) {
      return Text(
        widget.hintText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MoboType.hint(
          colors.isDark ? Colors.grey[400]! : Colors.grey[600]!,
          size: 15,
          italic: true,
        ),
      );
    }

    final visible = _selected.take(widget.maxVisibleChips).toList();
    final hidden = _selected.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final item in visible) _chip(colors, item),
        if (hidden > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.isDark ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(MoboRadius.chip),
            ),
            child: Text(
              '+$hidden more',
              style: MoboType.chip(
                colors.isDark ? Colors.grey[200]! : Colors.grey[700]!,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(MoboColors colors, T item) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: BorderRadius.circular(MoboRadius.chip),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.displayText(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoboType.chip(colors.primary),
            ),
          ),
          const SizedBox(width: 2),
          // Its own tap target, so removing a chip does not also open the
          // panel through the shell's tap.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled
                ? () => _setSelected(
                    _selected.where((e) => !_same(e, item)).toList(),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, double maxHeight) {
    final colors = context.mobo;

    // §7 popup: radius 16, elevation 4; a header row (title + "Done") with
    // a bottom border, then the search box and the list.
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.panelTitle ?? 'Select ${widget.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MoboType.fieldValue(
                        colors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _close,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, MoboSpacing.minTouchTarget),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Done',
                      style: MoboType.meta(
                        colors.primary,
                      ).copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: MoboPanelSearchBox(
                controller: _searchController,
                hintText: widget.searchHintText,
                onChanged: _onQueryChanged,
              ),
            ),
            Flexible(child: _buildList(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(MoboColors colors) {
    final items = _visibleItems;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          heightFactor: 1,
          child: Text(
            _query.isEmpty ? 'No options' : 'No matches',
            style: MoboType.body(colors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _isSelected(item);
        return InkWell(
          onTap: () => _toggle(item),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.displayText(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoboType.body(colors.textPrimary),
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggle(item),
                  activeColor: colors.primary,
                  side: BorderSide(color: colors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MoboRadius.checkbox),
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
