import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';

/// Animated full-width banner that appears at the top of the main shell.
///
/// - Goes offline → slides down an orange bar with "No internet connection".
/// - Comes back online → bar turns green with "Back online", then slides up
///   after 3 seconds.
///
/// The widget has zero height when fully online so it never takes up space.
class GlobalNetworkBanner extends StatefulWidget {
  const GlobalNetworkBanner({super.key});

  @override
  State<GlobalNetworkBanner> createState() => _GlobalNetworkBannerState();
}

class _GlobalNetworkBannerState extends State<GlobalNetworkBanner> {
  bool _isOnline = true;
  bool _showBackOnline = false;
  Timer? _hideTimer;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    // Seed from a quick async probe so the banner reflects reality on first build.
    ConnectivityService.instance.hasInternetAccess().then((v) {
      if (mounted && _isOnline != v) setState(() => _isOnline = v);
    });

    _sub = ConnectivityService.instance.onInternetChanged.listen((isOnline) {
      if (!mounted) return;
      setState(() {
        if (isOnline && !_isOnline) {
          // Transitioned offline → online: show green banner for 3 s.
          _showBackOnline = true;
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showBackOnline = false);
          });
        } else if (!isOnline) {
          // Went offline: cancel any pending "back online" hide timer.
          _hideTimer?.cancel();
          _showBackOnline = false;
        }
        _isOnline = isOnline;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showOffline = !_isOnline;
    final bool visible = showOffline || _showBackOnline;

    final Color bannerColor = showOffline
        ? StatusColors.orange // offline
        : StatusColors.green; // back online

    final String label = showOffline
        ? 'No internet connection'
        : 'Back online — seamless experience restored';

    final IconData icon = showOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: visible ? 32 : 0,
      color: bannerColor,
      child: visible
          ? SafeArea(
              bottom: false,
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
