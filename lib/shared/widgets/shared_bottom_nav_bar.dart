import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

/// A collaborative bottom navigation bar that manages navigation between primary application branches.
class SharedBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const SharedBottomNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SnakeNavigationBar.color(
      behaviour: SnakeBarBehaviour.pinned,
      snakeShape: SnakeShape.indicator,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      selectedItemColor: isDark ? Colors.white : colorScheme.primary,
      unselectedItemColor: isDark ? Colors.grey[400] : Colors.black,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: navigationShell.currentIndex,
      onTap: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      items: _buildNavItems(context, isDark),
      snakeViewColor: colorScheme.primary,
      unselectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      selectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : colorScheme.primary,
      ),
      shadowColor: isDark ? Colors.black26 : Colors.grey[200]!,
      elevation: 8,
      height: 70,
    );
  }

  List<BottomNavigationBarItem> _buildNavItems(
    BuildContext context,
    bool isDark,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return [
      _buildItem(
        icon: HugeIcons.strokeRoundedDashboardSquare01,
        label: 'Dashboard',
        isDark: isDark,
        primaryColor: primaryColor,
      ),
      _buildItem(
        icon: HugeIcons.strokeRoundedPackageOpen,
        label: 'Inventory',
        isDark: isDark,
        primaryColor: primaryColor,
      ),
      _buildItem(
        icon: Icons.compare_arrows,
        label: 'Transfer',
        isDark: isDark,
        primaryColor: primaryColor,
      ),
      _buildItem(
        icon: Icons.autorenew_outlined,
        label: 'Replenish',
        isDark: isDark,
        primaryColor: primaryColor,
      ),
      _buildItem(
        icon: Icons.history,
        label: 'History',
        isDark: isDark,
        primaryColor: primaryColor,
      ),
    ];
  }

  BottomNavigationBarItem _buildItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryColor,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: Icon(icon),
      ),
      label: label,
      activeIcon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: Icon(icon, color: isDark ? Colors.white : primaryColor),
      ),
    );
  }
}
