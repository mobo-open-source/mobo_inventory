import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A full-screen error widget displayed when the server is unreachable or a connection error occurs.
class ConnectionStatusWidget extends StatelessWidget {
  final bool serverUnreachable;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ConnectionStatusWidget({
    super.key,
    this.serverUnreachable = false,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red[900]!.withOpacity(0.2)
                    : Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                serverUnreachable
                    ? HugeIcons.strokeRoundedWifiDisconnected02
                    : HugeIcons.strokeRoundedAlert02,
                size: 40,
                color: isDark ? Colors.red[300] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              serverUnreachable ? 'Server Unreachable' : 'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              customMessage ??
                  (serverUnreachable
                      ? 'Unable to connect to the server.\nPlease check your internet connection.'
                      : 'Something went wrong.\nPlease try again.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
