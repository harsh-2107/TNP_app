import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_bottom_navigation.dart';

/// Persistent scaffold shell hosting the bottom navigation bar around
/// Home / Resume / Add Resume / Notifications / Profile, used as the
/// `StatefulShellRoute.builder` in `core/routing/app_router.dart` so tab
/// switches preserve each branch's navigation stack.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    AppNavItem(icon: Icons.home_rounded, label: 'Home'),
    AppNavItem(icon: Icons.picture_as_pdf_rounded, label: 'Resume'),
    AppNavItem(icon: Icons.track_changes_rounded, label: 'Tracker'),
    AppNavItem(icon: Icons.notifications_rounded, label: 'Notify'),
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
