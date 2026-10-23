import 'package:flutter/material.dart';

import '../mobo/mobo_text_field.dart';

/// The create/edit form text field.
///
/// Now drawn by the Mobo design system — the shared field shell supplies the
/// label, the 48pt box, the focus and error borders and the error message, so
/// every form field in the app looks the same and a change to the system
/// lands on all of them at once.
///
/// The constructor is unchanged so existing forms keep compiling. [isDark]
/// and [showBorder] are accepted but ignored: the shell resolves light and
/// dark from `Theme.of(context).brightness` itself, and its border is part of
/// the system rather than something a call site decides. They can be dropped
/// from the call sites whenever those files are next touched.
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool isDark;

  /// Marks the label with a red asterisk. Explicit rather than inferred from
  /// [validator], since optional fields here carry validators too.
  final bool isRequired;
  final bool showBorder;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.isDark = false,
    this.isRequired = false,
    this.showBorder = false,
    this.keyboardType,
    this.maxLines = 1,
    this.suffixIcon,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MoboTextField(
      controller: controller,
      label: labelText,
      isRequired: isRequired,
      hintText: hintText,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      suffixIcon: suffixIcon,
    );
  }
}
