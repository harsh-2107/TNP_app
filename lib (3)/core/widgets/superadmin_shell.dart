import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_bottom_navigation.dart';

/// Persistent scaffold shell hosting the bottom navigation bar around
/// Superadmin Dashboard / Students / Drives / Applications / Logs
class SuperadminShell extends StatelessWidget {
  const SuperadminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    AppNavItem(icon: Icons.dashboard_rounded, label: 'Dash'),
    AppNavItem(icon: Icons.people_rounded, label: 'Students'),
    AppNavItem(icon: Icons.history_rounded, label: 'Logs'),
    AppNavItem(icon: Icons.account_circle_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigation(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
