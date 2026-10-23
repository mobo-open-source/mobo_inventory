import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';

/// A generic placeholder widget displayed when a list or view has no data.
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? lottieAsset;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.lottieAsset,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget illustration;
    if (lottieAsset != null && lottieAsset!.isNotEmpty) {
      illustration = Lottie.asset(
        lottieAsset!,
        width: 220,
        height: 220,
        repeat: true,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) {
          return Icon(
            Icons.inbox_outlined,
            size: 96,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          );
        },
      );
    } else {
      illustration = Icon(
        Icons.inbox_outlined,
        size: 96,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      );
    }

    return Padding(
      padding: padding,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              illustration,
              // Room under the animation, so the message and the action sit
              // a little lower than the illustration.
              const SizedBox(height: 36),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(color: theme.primaryColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
