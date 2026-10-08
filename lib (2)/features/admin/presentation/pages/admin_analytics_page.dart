import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../controllers/admin_analytics_controller.dart';
import '../../domain/admin_analytics_model.dart';

class AdminAnalyticsPage extends ConsumerStatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  ConsumerState<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends ConsumerState<AdminAnalyticsPage> {
  String? _selectedDriveId; // null means cumulative

  @override
  Widget build(BuildContext context) {
    final drivesAsync = ref.watch(adminDrivesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: drivesAsync.when(
        data: (drives) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDriveSelector(drives),
                const SizedBox(height: 24),
                _buildAnalyticsContent(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Text(
            'Failed to load drives:\n$err',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildDriveSelector(List<dynamic> drives) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedDriveId,
          hint: const Text('Select a drive'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Cumulative (All Drives)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...drives.map((drive) {
              final id = drive['id'] as String;
              final name = drive['company_name'] as String;
              final role = drive['role_title'] as String;
              return DropdownMenuItem<String?>(
                value: id,
                child: Text('$name - $role'),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedDriveId = val;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final analyticsAsync = _selectedDriveId == null
        ? ref.watch(cumulativeAnalyticsProvider)
        : ref.watch(specificDriveAnalyticsProvider(_selectedDriveId!));

    return analyticsAsync.when(
      data: (data) => _buildCharts(data),
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => SizedBox(
        height: 300,
        child: Center(
          child: Text(
            'Failed to load analytics:\n$err',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCharts(AdminAnalyticsModel data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryCards(data),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Eligibility Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green.shade400,
                        value: data.eligibleStudents.toDouble(),
                        title: '${data.eligibleStudents}',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.red.shade400,
                        value: data.ineligibleStudents.toDouble(),
                        title: '${data.ineligibleStudents}',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.green.shade400, 'Eligible'),
                  const SizedBox(width: 24),
                  _buildLegend(Colors.red.shade400, 'Ineligible'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Applications (Out of Eligible)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (data.appliedOutOfEligible + data.unappliedButEligible + data.rejectedButEligible).toDouble() + 10,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Text('Applied');
                              case 1:
                                return const Text('Unapplied');
                              case 2:
                                return const Text('Rejected');
                              default:
                                return const Text('');
                            }
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: data.appliedOutOfEligible.toDouble(),
                            color: AppColors.primary,
                            width: 32,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: (data.appliedOutOfEligible + data.unappliedButEligible + data.rejectedButEligible).toDouble(),
                              color: AppColors.surfaceMuted,
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: data.unappliedButEligible.toDouble(),
                            color: Colors.orange.shade400,
                            width: 32,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: (data.appliedOutOfEligible + data.unappliedButEligible + data.rejectedButEligible).toDouble(),
                              color: AppColors.surfaceMuted,
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: data.rejectedButEligible.toDouble(),
                            color: Colors.red.shade400,
                            width: 32,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: (data.appliedOutOfEligible + data.unappliedButEligible + data.rejectedButEligible).toDouble(),
                              color: AppColors.surfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(AdminAnalyticsModel data) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Total Students',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.totalStudents}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Total Applied',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.appliedOutOfEligible}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Total Rejected',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.rejectedButEligible}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
