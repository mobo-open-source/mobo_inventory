import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/widgets/odoo_avatar.dart';

class DashboardGreetingCard extends StatelessWidget {
  final String? userName;
  final String? userAvatar; // Changed from Uint8List?
  final bool isLoading;
  final bool isOffline;

  const DashboardGreetingCard({
    super.key,
    this.userName,
    this.userAvatar,
    this.isLoading = false,
    this.isOffline = false,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _buildGreetingText() {
    if (userName == null || userName!.trim().isEmpty || userName == 'User') {
      return '${_getGreeting()}!';
    }

    final firstName = userName!.split(' ')[0];
    return '${_getGreeting()} $firstName!';
  }

  String _getSubtitleText() {
    if (isOffline) {
      return 'Working offline - some features may be limited';
    }
    return 'Manage Your Inventory Operations Efficiently';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double rs(double size) {
      final w = MediaQuery.of(context).size.width;
      final scale = (w / 390.0).clamp(0.85, 1.2);
      return size * scale;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isLoading
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.white.withOpacity(0.3),
                            highlightColor: Colors.white.withOpacity(0.6),
                            child: Container(
                              height: 24,
                              width: 180,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Shimmer.fromColors(
                            baseColor: Colors.white.withOpacity(0.2),
                            highlightColor: Colors.white.withOpacity(0.4),
                            child: Container(
                              height: 16,
                              width: 250,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _buildGreetingText(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: rs(19),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getSubtitleText(),
                            style: TextStyle(
                              color: isOffline
                                  ? Colors.orange[200]
                                  : Colors.white.withOpacity(0.9),
                              fontSize: rs(13),
                              letterSpacing: 0,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.3),
        highlightColor: Colors.white.withOpacity(0.6),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: OdooAvatar(
        imageBase64: userAvatar,
        size: 52,
        iconSize: 28,
        placeholderColor: Colors.white.withOpacity(0.2),
        iconColor: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(26),
      ),
    );
  }
}
