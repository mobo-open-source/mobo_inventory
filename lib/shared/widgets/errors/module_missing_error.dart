import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ModuleMissingError extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onContactAdmin;

  const ModuleMissingError({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onContactAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMissingModule =
        errorMessage.contains('Missing Module') ||
        errorMessage.contains('Required App') ||
        errorMessage.contains('not installed');
    // §20: orange for a missing module, the same skeleton in red otherwise.
    final semanticColor = isMissingModule
        ? StatusColors.orange
        : StatusColors.red;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: semanticColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMissingModule
                          ? Icons.extension_off
                          : Icons.error_outline,
                      size: 60,
                      color: semanticColor,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            Text(
              isMissingModule ? 'Module Not Installed' : 'Error',
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
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: semanticColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
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
                    ),
                  ),
                if (onContactAdmin != null)
                  ElevatedButton.icon(
                    onPressed: onContactAdmin,
                    icon: const Icon(Icons.support_agent, size: 20),
                    label: const Text('Contact Admin'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      backgroundColor: semanticColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),

            if (isMissingModule) ...[
              const SizedBox(height: 24),
              Text(
                'Your administrator needs to install the required Odoo app/module on the server.',
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
}
