import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Displays a blocking dialog for an account that cannot use this app.
///
/// [onClose] runs after the dialog has been popped — callers reached
/// mid-flow (adding a second account, switching accounts) use it to leave
/// that flow, instead of leaving the user on a form for an account that can
/// never sign in here.
Future<void> showAccessDeniedDialog(
  BuildContext context, {
  required String message,
  String title = 'Access Denied',
  String actionLabel = 'OK',
  VoidCallback? onClose,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: StatusColors.red, size: 26),
            const SizedBox(width: 10),
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
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onClose?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
