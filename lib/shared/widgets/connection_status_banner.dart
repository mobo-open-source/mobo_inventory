import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';

/// A persistent banner widget that notifies the user when the application is offline.
class ConnectionStatusBanner extends StatefulWidget
    implements PreferredSizeWidget {
  const ConnectionStatusBanner({super.key});

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();

  @override
  Size get preferredSize => const Size.fromHeight(22);
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _online = true;
  late final Stream<bool> _internetStream;

  @override
  void initState() {
    super.initState();
    _internetStream = ConnectivityService.instance.onInternetChanged;

    ConnectivityService.instance.hasInternetAccess().then((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<bool>(
      stream: _internetStream,
      initialData: _online,
      builder: (context, internetSnap) {
        final online = internetSnap.data ?? true;
        if (online) return const SizedBox();
        const String message =
            "You're offline. Check your internet connection.";
        return Container(
          height: 22,
          width: double.infinity,
          alignment: Alignment.center,
          color: isDark ? const Color(0xFF3B2C2C) : const Color(0xFFFFEAEA),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFFFB3B3) : const Color(0xFFB00020),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
