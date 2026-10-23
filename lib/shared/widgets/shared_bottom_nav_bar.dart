import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

/// A collaborative bottom navigation bar that manages navigation between primary application branches.
///
/// Shows only the branches in [visibleBranches] (the shell's branch indices,
/// in order), so tabs the user's Odoo access rights don't allow can be left
/// out without touching the router: a tap on nav position `i` opens branch
/// `visibleBranches[i]`.
class SharedBottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  /// Branch indices to show, ascending. Defaults to every branch.
  final List<int> visibleBranches;

  /// Whether to use the shorter landscape layout ([compactHeight]).
  final bool compact;

  /// Height of the bar on a normal-height screen (CLAUDE.md §13).
  static const double regularHeight = 70;

  /// Height on a short (landscape phone) screen, where 70px plus the app bar
  /// would take a third of the height. A deliberate landscape-only exception
  /// to §13; labels keep their regular sizes.
  static const double compactHeight = 56;

  static const List<int> allBranches = [0, 1, 2, 3, 4];

  /// Icon and label of each branch, in branch order (see app_router.dart).
  static const List<({IconData icon, String label})> _tabs = [
    (icon: HugeIcons.strokeRoundedDashboardSquare01, label: 'Dashboard'),
    (icon: HugeIcons.strokeRoundedPackageOpen, label: 'Inventory'),
    (icon: Icons.compare_arrows, label: 'Transfer'),
    (icon: Icons.autorenew_outlined, label: 'Replenish'),
    (icon: Icons.history, label: 'History'),
  ];

  const SharedBottomNavBar({
    super.key,
    required this.navigationShell,
    this.visibleBranches = allBranches,
    this.compact = false,
  });

  /// Nav position of [branch] among [visible], or 0 (Dashboard) when it is
  /// not shown — the shell is about to move off such a branch.
  static int positionOf(int branch, List<int> visible) {
    final position = visible.indexOf(branch);
    return position < 0 ? 0 : position;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final branches = visibleBranches
        .where((branch) => branch >= 0 && branch < _tabs.length)
        .toList();

    return SnakeNavigationBar.color(
      // A new set of tabs is a new bar: the snake indicator keeps its
      // position in state and would otherwise start from a stale slot.
      key: ValueKey('nav_${branches.join('_')}'),
      behaviour: SnakeBarBehaviour.pinned,
      snakeShape: SnakeShape.indicator,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      selectedItemColor: isDark ? Colors.white : colorScheme.primary,
      unselectedItemColor: isDark ? Colors.grey[400] : Colors.black,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: positionOf(navigationShell.currentIndex, branches),
      onTap: (position) {
        final branch = branches[position];
        navigationShell.goBranch(
          branch,
          initialLocation: branch == navigationShell.currentIndex,
        );
      },
      items: [
        for (final branch in branches)
          _buildItem(
            icon: _tabs[branch].icon,
            label: _tabs[branch].label,
            isDark: isDark,
            primaryColor: Theme.of(context).primaryColor,
          ),
      ],
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
      height: compact ? compactHeight : regularHeight,
    );
  }

  BottomNavigationBarItem _buildItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryColor,
  }) {
    // Less air around the icon in the shorter bar, so icon + label still fit.
    final iconPadding = EdgeInsets.symmetric(vertical: compact ? 2.0 : 5.0);
    return BottomNavigationBarItem(
      icon: Padding(padding: iconPadding, child: Icon(icon)),
      label: label,
      activeIcon: Padding(
        padding: iconPadding,
        child: Icon(icon, color: isDark ? Colors.white : primaryColor),
      ),
    );
  }
}
