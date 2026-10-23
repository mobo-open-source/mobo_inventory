import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/mobo_tokens.dart';
import 'mobo_field_shell.dart';

/// A text field in the Mobo field shell.
///
/// Built on a [FormField] so it takes part in an enclosing [Form] exactly as
/// a `TextFormField` would, while the shell — not the input — draws the
/// border, the label and the error message. The inner field is stripped of
/// every Material border and of its own error text, so nothing is drawn
/// twice.
class MoboTextField extends StatefulWidget {
  const MoboTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.isRequired = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autovalidateMode,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.focusNode,
    this.onTap,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;

  final String? label;
  final String? hintText;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  final bool isRequired;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;

  final AutovalidateMode? autovalidateMode;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  final VoidCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<MoboTextField> createState() => _MoboTextFieldState();
}

class _MoboTextFieldState extends State<MoboTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mobo;

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled,
      builder: (field) {
        return MoboFieldShell(
          label: widget.label,
          isRequired: widget.isRequired,
          errorText: field.errorText,
          enabled: widget.enabled,
          isFocused: _focusNode.hasFocus,
          child: Row(
            crossAxisAlignment: widget.maxLines == 1
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (widget.prefixIcon != null) ...[
                widget.prefixIcon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  maxLength: widget.maxLength,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  onTap: widget.onTap,
                  onSubmitted: widget.onFieldSubmitted,
                  cursorColor: colors.primary,
                  style: MoboType.fieldValue(colors.textPrimary),
                  onChanged: (value) {
                    // Keeps the enclosing Form's view of this field in step
                    // with the controller the caller owns.
                    field.didChange(value);
                    widget.onChanged?.call(value);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    counterText: '',
                    hintText: widget.hintText,
                    hintStyle: MoboType.hint(
                      colors.isDark ? Colors.grey[400]! : Colors.grey[600]!,
                      size: 16,
                      italic: true,
                    ),
                    // The shell owns every border and the error message, so
                    // the input must not draw either.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
              if (widget.suffixIcon != null) ...[
                const SizedBox(width: 8),
                widget.suffixIcon!,
              ],
            ],
          ),
        );
      },
    );
  }
}
