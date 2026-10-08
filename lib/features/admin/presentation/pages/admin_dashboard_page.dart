import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:place_row/core/theme/app_colors.dart';

import '../../../../core/routing/route_names.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 7,
        shadowColor: AppColors.shadowDarkDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _DashboardTile(
            title: 'Manage Placement Drives',
            subtitle: 'Create and list drives, set eligibility rules',
            icon: Icons.business_center,
            onTap: () {
              context.push(RoutePaths.adminDrives);
            },
          ),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'View Applicants',
            subtitle: 'Filter applicants, export to CSV, send reminders',
            icon: Icons.people,
            onTap: () {
              context.push(RoutePaths.adminApplicants);
            },
          ),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'Active Students Tracker',
            subtitle: 'Live view of student activity on the platform',
            icon: Icons.radar,
            onTap: () {
              context.push(RoutePaths.adminActiveStudents);
            },
          ),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'System Logs',
            subtitle: 'View admin action history and audit trails',
            icon: Icons.history,
            onTap: () {
              context.push(RoutePaths.adminLogs);
            },
          ),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'Analytics Dashboard',
            subtitle: 'View cumulative and per-drive placement statistics',
            icon: Icons.pie_chart,
            onTap: () {
              context.push(RoutePaths.adminAnalytics);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(RoutePaths.adminCreateDrive);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Drive'),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
