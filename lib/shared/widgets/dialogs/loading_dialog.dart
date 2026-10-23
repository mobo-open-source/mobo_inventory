import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../loaders/loading_widget.dart';

class LoadingDialog {
  /// The loading dialogs showing, newest last, so [hide] closes one of them
  /// rather than whatever route is on top — after a dialog was pushed above
  /// the loader, or with no loader showing, that was the wrong one (even the
  /// page itself).
  static final List<Route<void>> _open = [];

  static void show(BuildContext context, {String? message}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: IntrinsicWidth(
            child: Card(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LoadingWidget(
                      color: theme.primaryColor,
                      size: 48,
                      variant: LoadingVariant.staggeredDots,
                    ),
                    if (message != null && message.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _open.add(route);
    navigator.push(route).whenComplete(() => _open.remove(route));
  }

  static void hide(BuildContext context) {
    while (_open.isNotEmpty) {
      final route = _open.removeLast();
      final navigator = route.navigator;
      if (!route.isActive || navigator == null) continue;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
      return;
    }
  }
}
