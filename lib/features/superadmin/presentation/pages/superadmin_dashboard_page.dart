import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_row/features/superadmin/presentation/pages/superadmin_admins_page.dart';
import 'package:place_row/features/superadmin/presentation/pages/superadmin_drives_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../admin/presentation/pages/admin_active_students_page.dart';
import '../../../admin/presentation/pages/admin_applicants_page.dart';
import '../controllers/superadmin_dashboard_controller.dart';

class SuperadminDashboardPage extends ConsumerWidget {
  const SuperadminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(superadminStatsProvider);
    final dbOverviewAsync = ref.watch(superadminDatabaseOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Superadmin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.background),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(superadminStatsProvider);
          ref.invalidate(superadminDatabaseOverviewProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'System Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) {
                return _buildStatsGrid(stats, context);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading stats: $e')),
            ),
            const SizedBox(height: 32),
            const Text(
              'Database Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            dbOverviewAsync.when(
              data: (overview) {
                return _buildDbOverviewGrid(overview);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) =>
                  Center(child: Text('Error loading db overview: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, BuildContext context) {
    final counts = stats['counts'] ?? {};
    final totalStudents = counts['total_students'] ?? 0;
    final admins =
        (counts['total_admins'] ?? 0) + (counts['total_superadmins'] ?? 0);
    final totalDrives = counts['total_drives'] ?? 0;
    final applications = counts['total_applications'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          title: 'Total Students',
          value: totalStudents.toString(),
          icon: Icons.people,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminActiveStudentsPage(),
              ),
            );
          },
        ),
        _StatCard(
          title: 'Active Drives',
          value: totalDrives.toString(),
          icon: Icons.business_center,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuperadminDrivesPage()),
            );
          },
        ),
        _StatCard(
          title: 'Applications',
          value: applications.toString(),
          icon: Icons.description,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminApplicantsPage()),
            );
          },
        ),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => SuperadminAdminsPage()),
          ),
          child: _StatCard(
            title: 'Admins',
            value: admins.toString(),
            icon: Icons.security,
            color: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildDbOverviewGrid(Map<String, dynamic> overview) {
    final Map<String, dynamic> tables = overview['tables'] ?? {};

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final key = tables.keys.elementAt(index);
        final val = tables[key];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                key.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  val.toString(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
