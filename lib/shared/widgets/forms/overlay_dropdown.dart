import 'package:flutter/material.dart';

/// A data model representing an option within an [OverlayDropdownField].
class OverlayDropdownOption<T> {
  final T value;
  final String label;
  const OverlayDropdownOption({required this.value, required this.label});
}

/// A custom dropdown field that uses an overlay to display its options, providing more control over position and styling.
class OverlayDropdownField<T> extends StatefulWidget {
  final T? value;
  final String labelText;
  final String hintText;
  final List<OverlayDropdownOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool isDark;
  final bool enabled;

  const OverlayDropdownField({
    super.key,
    required this.value,
    required this.labelText,
    required this.hintText,
    required this.options,
    required this.onChanged,
    this.validator,
    this.isDark = false,
    this.enabled = true,
  });

  @override
  State<OverlayDropdownField<T>> createState() =>
      _OverlayDropdownFieldState<T>();
}

class _OverlayDropdownFieldState<T> extends State<OverlayDropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleOverlay(BuildContext context) {
    if (!widget.enabled) return;
    if (_overlayEntry == null) {
      _showDropdownOverlay(context);
    } else {
      _removeOverlay();
    }
  }

  void _showDropdownOverlay(BuildContext context) {
    if (_overlayEntry != null) return;
    if (widget.options.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final fieldWidth =
        renderBox?.size.width ?? MediaQuery.of(context).size.width;
    final isDark = widget.isDark;

    const double itemHeight = 44.0;
    const double listPadding = 16.0;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
            ),
          ),
          Positioned(
            width: fieldWidth,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 58),
              child: Material(
                elevation: 12.0,
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                shadowColor: Colors.black.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    maxHeight: itemHeight * 5 + listPadding,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemExtent: itemHeight,
                    itemCount: widget.options.length,
                    itemBuilder: (ctx, index) {
                      final opt = widget.options[index];
                      return InkWell(
                        onTap: () {
                          widget.onChanged?.call(opt.value);
                          _removeOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Text(
                            opt.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      final overlayState = Overlay.maybeOf(context);
      if (overlayState != null && overlayState.mounted) {
        overlayState.insert(_overlayEntry!);
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final theme = Theme.of(context);
    OverlayDropdownOption<T>? current;
    try {
      current = widget.options.firstWhere((o) => o.value == widget.value);
    } catch (_) {
      current = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.labelText,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _layerLink,
          child: FormField<T>(
            initialValue: widget.value,
            validator: widget.validator,
            builder: (field) {
              if (field.value != widget.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  field.didChange(widget.value);
                });
              }

              final String display =
                  (current != null && current.label.isNotEmpty)
                  ? current.label
                  : widget.hintText;
              final bool isEmpty = current == null || current.label.isEmpty;

              return InkWell(
                onTap: () => _toggleOverlay(context),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  isEmpty: isEmpty,
                  decoration: InputDecoration(
                    enabled: widget.enabled,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 1,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xffF8FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    errorText: field.errorText,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          display,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isEmpty
                                ? (isDark ? Colors.white54 : Colors.grey[600])
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xff000000)),
                            fontStyle: isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _overlayEntry == null
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 20,
                        color: widget.enabled ? Colors.black54 : Colors.black26,
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
}
