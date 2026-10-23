import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// A highly customizable dialog component used throughout the app for alerts, confirmations, and simple inputs.
class CommonDialog extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final bool showInput;
  final String? inputHint;
  final TextEditingController? controller;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructivePrimary;

  final bool topIconCentered;

  final Widget? body;

  const CommonDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.showInput = false,
    this.inputHint,
    this.controller,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.destructivePrimary = false,
    this.topIconCentered = false,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    final primaryBg = primary;
    final primaryFg = Colors.white;

    // Destructive actions (discard, cancel) use an orange "caution" icon
    // rather than red — red is reserved for the primary button itself.
    final iconColor = destructivePrimary ? StatusColors.orange : primary;

    // A plain confirm (no custom body or input) is a compact action dialog.
    final isCompact = body == null && !showInput;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topIconCentered) ...[
              if (icon != null) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ],
            if (body != null) ...[const SizedBox(height: 14), body!],
            if (showInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: inputHint ?? 'Placeholder',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : AppTheme.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (secondaryLabel != null && onSecondary != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: primary, width: 1.5),
                        backgroundColor: isDark
                            ? AppTheme.darkSurface
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: primaryBg,
                      foregroundColor: primaryFg,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // A button's textStyle replaces the theme's rather than
                      // merging with it, so it must name the font itself.
                      textStyle: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
    IconData? icon,
    bool topIconCentered = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        topIconCentered: topIconCentered,
        primaryLabel: confirmText,
        onPrimary: () => ctx.pop(true),
        secondaryLabel: cancelText,
        onSecondary: () => ctx.pop(false),
        destructivePrimary: destructive,
      ),
    );
  }

  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? message,
    String placeholder = 'Enter value',
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        showInput: true,
        controller: controller,
        inputHint: placeholder,
        primaryLabel: confirmText,
        onPrimary: () => ctx.pop(controller.text.trim()),
        secondaryLabel: cancelText,
        onSecondary: () => ctx.pop(null),
      ),
    );
  }
}
