import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../core/services/error_manager.dart';

/// A versatile error display widget that handles various error types and provides a retry mechanism.
class UniversalErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;

  const UniversalErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    final errorInfo = ErrorManager.analyzeError(error);
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: _buildAnimation(errorInfo),
            ),
            const SizedBox(height: 24),

            Text(
              errorInfo.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: errorInfo.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: errorInfo.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                errorInfo.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      side: BorderSide(color: errorInfo.color),
                    ),
                  ),
                if (onContactSupport != null ||
                    errorInfo.type == ErrorType.moduleNotInstalled)
                  ElevatedButton.icon(
                    onPressed: onContactSupport ?? () {},
                    icon: const Icon(Icons.support_agent, size: 20),
                    label: const Text('Contact Admin'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      backgroundColor: errorInfo.color,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),

            if (errorInfo.type == ErrorType.moduleNotInstalled) ...[
              const SizedBox(height: 24),
              Text(
                'Pull to refresh or tap Retry after the module is installed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimation(ErrorInfo errorInfo) {
    String? animationUrl = _getAnimationUrl(errorInfo.type);

    if (animationUrl != null) {
      return Lottie.network(
        animationUrl,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon(errorInfo);
        },
      );
    }

    return _buildFallbackIcon(errorInfo);
  }

  Widget _buildFallbackIcon(ErrorInfo errorInfo) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: errorInfo.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(errorInfo.icon, size: 60, color: errorInfo.color),
          ),
        );
      },
    );
  }

  String? _getAnimationUrl(ErrorType type) {
    return null;
  }
}
