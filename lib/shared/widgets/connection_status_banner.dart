import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';

/// Slim connectivity indicator sized to sit in an [AppBar.bottom].
///
/// Renders nothing while online, and a thin orange bar while offline.
class ConnectionStatusBanner extends StatefulWidget
    implements PreferredSizeWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(22);

  @override
  State<ConnectionStatusBanner> createState() =>
      _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _isOnline = true;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.hasInternetAccess().then((online) {
      if (mounted && _isOnline != online) setState(() => _isOnline = online);
    });
    _sub = ConnectivityService.instance.onInternetChanged.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    return Container(
      height: widget.preferredSize.height,
      width: double.infinity,
      color: StatusColors.orange,
      alignment: Alignment.center,
      child: const Text(
        'No internet connection',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
