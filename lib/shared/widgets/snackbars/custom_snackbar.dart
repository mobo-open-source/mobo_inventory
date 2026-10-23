import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum SnackbarType { info, success, warning, error }

/// A utility class for displaying styled snackbars for success, error, and informational messages.
class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showOverlaySnackbar(context, title, message, type, duration);
  }

  static void _showOverlaySnackbar(
    BuildContext context,
    String title,
    String message,
    SnackbarType type,
    Duration duration,
  ) {
    try {
      if (!context.mounted) {
        return;
      }

      bool isDark = false;
      try {
        isDark = Theme.of(context).brightness == Brightness.dark;
      } catch (e) {}

      final colors = _getColorsForType(type, isDark);

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.1),
        builder: (dialogContext) {
          // Closes this snackbar only. `Navigator.pop` closes whatever route
          // is on top: once the snackbar was dismissed by a tap outside it
          // (and was still animating out), or with a route pushed above it,
          // the timer closed the page underneath instead.
          final route = ModalRoute.of(dialogContext);
          void _safePop() {
            final navigator = route?.navigator;
            if (route == null || navigator == null || !route.isActive) return;
            try {
              if (route.isCurrent) {
                navigator.pop();
              } else {
                navigator.removeRoute(route);
              }
            } catch (e) {}
          }

          Future.delayed(duration, () {
            _safePop();
          });

          return Material(
            color: Colors.transparent,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                onDismissed: (direction) {
                  _safePop();
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    bottom: 100,
                    left: 16,
                    right: 16,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.iconBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            colors.icon,
                            size: 16,
                            color: colors.iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[100],
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _safePop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[100],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {}
  }

  static _SnackbarColors _getColorsForType(SnackbarType type, bool isDark) {
    switch (type) {
      case SnackbarType.info:
        return _SnackbarColors(
          icon: Icons.info_outline,
          iconColor: StatusColors.infoIcon,
          iconBackgroundColor: StatusColors.backgroundDark(StatusColors.blue),
          backgroundColor: isDark
              ? const Color(0xFF2D3748)
              : const Color(0xFF4A5568),
        );
      case SnackbarType.success:
        return _SnackbarColors(
          icon: Icons.check_circle_outline,
          iconColor: StatusColors.successIcon,
          iconBackgroundColor: StatusColors.backgroundDark(StatusColors.green),
          backgroundColor: isDark
              ? const Color(0xFF2D4A3D)
              : const Color(0xFF4A6B5A),
        );
      case SnackbarType.warning:
        return _SnackbarColors(
          icon: Icons.warning_outlined,
          iconColor: StatusColors.warningIcon,
          iconBackgroundColor: StatusColors.backgroundDark(StatusColors.orange),
          backgroundColor: isDark
              ? const Color(0xFF4A3D2D)
              : const Color(0xFF6B5A4A),
        );
      case SnackbarType.error:
        return _SnackbarColors(
          icon: Icons.error_outline,
          iconColor: StatusColors.errorIcon,
          iconBackgroundColor: StatusColors.backgroundDark(StatusColors.red),
          backgroundColor: isDark
              ? const Color(0xFF4A2D2D)
              : const Color(0xFF6B4A4A),
        );
    }
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      title: 'Success',
      message: message,
      type: SnackbarType.success,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Error',
      message: message,
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      title: 'Info',
      message: message,
      type: SnackbarType.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      title: 'Warning',
      message: message,
      type: SnackbarType.warning,
      duration: const Duration(seconds: 4),
    );
  }

  static void showOffline(BuildContext context) {
    show(
      context: context,
      title: 'You are offline',
      message:
          'No internet connection. Please check your Wi-Fi or mobile data.',
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showServerUnreachable(BuildContext context) {
    show(
      context: context,
      title: 'Server unreachable',
      message:
          'Cannot reach the server. Please verify the server URL and your network connection.',
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }

  static void showNetworkError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Network Error',
      message: message,
      type: SnackbarType.error,
      duration: const Duration(seconds: 5),
    );
  }
}

class _SnackbarColors {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;

  _SnackbarColors({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
  });
}
