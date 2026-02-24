import 'package:flutter/material.dart';

class ModuleNotInstalledError extends StatelessWidget {
  final String moduleName;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;

  const ModuleNotInstalledError({
    super.key,
    required this.moduleName,
    this.customMessage,
    this.onRetry,
    this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.extension_off_rounded,
                      size: 60,
                      color: Colors.orange.shade700,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            Text(
              'Module Not Installed',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    moduleName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    customMessage ??
                        'The $moduleName module is not installed on your Odoo server.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This feature requires the module to be installed by your administrator.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                if (onContactSupport != null)
                  ElevatedButton.icon(
                    onPressed: onContactSupport,
                    icon: const Icon(Icons.support_agent, size: 20),
                    label: const Text('Contact Admin'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Need help? Contact your system administrator to install the required module.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
