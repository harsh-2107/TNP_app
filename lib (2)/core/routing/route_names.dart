/// Centralized route path & name constants. Never hardcode a route
/// string inline — always reference `RouteNames.x` / `RoutePaths.x` so
/// renaming a route is a one-line change.
class RoutePaths {
  const RoutePaths._();

  static const login = '/login';
  static const home = '/home';
  static const resume = '/resume';
  static const tracker = '/tracker';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const adminDashboard = '/admin';
  static const adminDrives = '/admin/drives';
  static const adminCreateDrive = '/admin/drives/create';
  static const adminApplicants = '/admin/applicants';
  static const adminActiveStudents = '/admin/students';
  static const adminLogs = '/admin/logs';
  static const adminAnalytics = '/admin/analytics';

  static const superadminDashboard = '/superadmin';
  static const superadminStudents = '/superadmin/students';
  static const superadminRoles = '/superadmin/roles';
  static const superadminDrives = '/superadmin/drives';
  static const superadminApplications = '/superadmin/applications';
  static const superadminLogs = '/superadmin/logs';
}

class RouteNames {
  const RouteNames._();

  static const login = 'login';
  static const home = 'home';
  static const resume = 'resume';
  static const tracker = 'tracker';
  static const notifications = 'notifications';
  static const profile = 'profile';
  static const editProfile = 'editProfile';
  static const adminDashboard = 'adminDashboard';
  static const adminDrives = 'adminDrives';
  static const adminCreateDrive = 'adminCreateDrive';
  static const adminApplicants = 'adminApplicants';
  static const adminActiveStudents = 'adminActiveStudents';
  static const adminLogs = 'adminLogs';
  static const adminAnalytics = 'adminAnalytics';

  static const superadminDashboard = 'superadminDashboard';
  static const superadminStudents = 'superadminStudents';
  static const superadminRoles = 'superadminRoles';
  static const superadminDrives = 'superadminDrives';
  static const superadminApplications = 'superadminApplications';
  static const superadminLogs = 'superadminLogs';
}
