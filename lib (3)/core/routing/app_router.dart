import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/home/presentation/pages/student_round_tracker_page.dart';
import '../../features/resume/presentation/pages/resume_page.dart';
import '../../features/admin/presentation/pages/admin_active_students_page.dart';
import '../../features/admin/presentation/pages/admin_applicants_page.dart';
import '../../features/admin/presentation/pages/admin_create_drive_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_drives_page.dart';
import '../../features/admin/presentation/pages/admin_logs_page.dart';
import '../../features/admin/presentation/pages/admin_analytics_page.dart';
import '../../features/superadmin/presentation/pages/superadmin_dashboard_page.dart';
import '../../features/superadmin/presentation/pages/superadmin_students_page.dart';
import '../../features/superadmin/presentation/pages/superadmin_drives_page.dart';
import '../../features/superadmin/presentation/pages/superadmin_logs_page.dart';
import '../widgets/main_shell.dart';
import '../widgets/superadmin_shell.dart';
import 'route_names.dart';

/// Root navigator key, exposed for cases outside the widget tree (e.g. a
/// push-notification tap handler) that need to navigate.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final _superadminShellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'superadmin_shell',
);

/// Centralized route table. All navigation should go through
/// `context.go(RoutePaths.x)` / `context.push(...)` — never construct a
/// [MaterialPageRoute] ad hoc inside a screen.

//earlier default page was home oage now changed to login page
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.login,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoading = authState.isLoading;
      if (isLoading) {
        return null;
      }
      // Splash/loading is handled by AppLoader in the shell.

      final isSignedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == RoutePaths.login;

      if (!isSignedIn && !isLoggingIn) return RoutePaths.login;

      if (isSignedIn) {
        final isAdmin = authState.value!.isAdmin;
        final isSuperadmin = authState.value!.isSuperadmin;
        final isGoingToAdmin = state.matchedLocation.startsWith('/admin');
        final isGoingToSuperadmin = state.matchedLocation.startsWith(
          '/superadmin',
        );
        final isGoingToStudentHome = state.matchedLocation == RoutePaths.home;

        if (isLoggingIn) {
          if (isSuperadmin) return RoutePaths.superadminDashboard;
          return isAdmin ? RoutePaths.adminDashboard : RoutePaths.home;
        }

        // Prevent admins/superadmins from getting stuck in student home
        if ((isAdmin || isSuperadmin) && isGoingToStudentHome) {
          return isSuperadmin
              ? RoutePaths.superadminDashboard
              : RoutePaths.adminDashboard;
        }

        // Prevent standard students from accessing admin or superadmin
        if (!isAdmin &&
            !isSuperadmin &&
            (isGoingToAdmin || isGoingToSuperadmin)) {
          return RoutePaths.home;
        }

        // Prevent normal admins from accessing superadmin routes
        if (isAdmin && !isSuperadmin && isGoingToSuperadmin) {
          return RoutePaths.adminDashboard;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.adminDashboard,
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: RoutePaths.adminDrives,
        name: RouteNames.adminDrives,
        builder: (context, state) => const AdminDrivesPage(),
      ),
      GoRoute(
        path: RoutePaths.adminCreateDrive,
        name: RouteNames.adminCreateDrive,
        builder: (context, state) => const AdminCreateDrivePage(),
      ),
      GoRoute(
        path: RoutePaths.adminApplicants,
        name: RouteNames.adminApplicants,
        builder: (context, state) => const AdminApplicantsPage(),
      ),
      GoRoute(
        path: RoutePaths.adminActiveStudents,
        name: RouteNames.adminActiveStudents,
        builder: (context, state) => const AdminActiveStudentsPage(),
      ),
      GoRoute(
        path: RoutePaths.adminLogs,
        name: RouteNames.adminLogs,
        builder: (context, state) => const AdminLogsPage(),
      ),
      GoRoute(
        path: RoutePaths.adminAnalytics,
        name: RouteNames.adminAnalytics,
        builder: (context, state) => const AdminAnalyticsPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.resume,
                name: RouteNames.resume,
                builder: (context, state) => const ResumePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.tracker,
                name: RouteNames.tracker,
                builder: (context, state) => const StudentRoundTrackerPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.notifications,
                name: RouteNames.notifications,
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: RouteNames.editProfile,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const EditProfilePage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            SuperadminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _superadminShellNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.superadminDashboard,
                name: RouteNames.superadminDashboard,
                builder: (context, state) => const SuperadminDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.superadminStudents,
                name: RouteNames.superadminStudents,
                builder: (context, state) => const SuperadminStudentsPage(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.superadminLogs,
                name: RouteNames.superadminLogs,
                builder: (context, state) => const SuperadminLogsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/superadmin/profile', // Reusing ProfilePage for now
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.superadminDrives,
        name: RouteNames.superadminDrives,
        builder: (context, state) => const SuperadminDrivesPage(),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
});

/// Bridges Riverpod's `AsyncValue<AppUser?>` auth state into a
/// [Listenable] so [GoRouter] re-evaluates `redirect` whenever sign-in
/// state changes.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
