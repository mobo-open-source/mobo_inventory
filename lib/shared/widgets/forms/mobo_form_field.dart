import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/const/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Labeled text field matching the mobo design system.
///
/// Uses a [FocusNode]-driven [AnimatedContainer] border so the red focus ring
/// sits on the outer container edge (never inside it), regardless of whether
/// a prefix icon is present.
class MoboFormField extends StatefulWidget {
  final String label;
  final bool isRequired;
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final dynamic prefixIcon;
  final Widget? suffixWidget;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool isDark;

  const MoboFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDark,
    this.isRequired = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixWidget,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<MoboFormField> createState() => _MoboFormFieldState();
}

class _MoboFormFieldState extends State<MoboFormField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        _buildInput(),
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

  Widget _buildInput() {
    final hasPrefixIcon = widget.prefixIcon != null;
    final isMultiline = widget.maxLines > 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      // Single-line fields are pinned to 50 px — same as MoboDateField —
      // so both sit at equal height when placed side-by-side in a Row.
      constraints: isMultiline
          ? const BoxConstraints()
          : const BoxConstraints(minHeight: 50, maxHeight: 50),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[850] : AppTheme.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _isFocused ? primaryColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TextFormField(
            focusNode: _focusNode,
            controller: widget.controller,
            maxLines: widget.maxLines,
            minLines: widget.maxLines > 1 ? widget.maxLines : 1,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            keyboardType:
                widget.maxLines > 1 ? TextInputType.multiline : widget.keyboardType,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            cursorColor: primaryColor,
            textAlignVertical:
                isMultiline ? null : TextAlignVertical.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              isDense: !isMultiline,
              hintText: widget.hintText,
              hintStyle: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              prefixIcon: hasPrefixIcon
                  ? Padding(
                      padding:
                          const EdgeInsets.only(left: 16, right: 12),
                      child: HugeIcon(
                        icon: widget.prefixIcon,
                        color: widget.isDark
                            ? Colors.grey[400]!
                            : Colors.grey[600]!,
                        size: 20,
                      ),
                    )
                  : null,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: isMultiline ? null : widget.suffixWidget,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: isMultiline
                  ? EdgeInsets.only(
                      left: hasPrefixIcon ? 0 : 16,
                      right: widget.suffixWidget != null ? 48 : 16,
                      top: 16,
                      bottom: 16,
                    )
                  : EdgeInsets.symmetric(
                      horizontal: hasPrefixIcon ? 0 : 16,
                      vertical: 16,
                    ),
            ),
            validator: widget.validator,
          ),
          if (widget.suffixWidget != null && isMultiline)
            Positioned(
              top: 0,
              right: 0,
              child: widget.suffixWidget!,
            ),
        ],
      ),
    );
  }
}
