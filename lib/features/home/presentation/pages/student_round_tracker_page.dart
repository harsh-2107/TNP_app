import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../data/job_repository.dart';

class StudentRoundTrackerPage extends ConsumerStatefulWidget {
  const StudentRoundTrackerPage({super.key});

  @override
  ConsumerState<StudentRoundTrackerPage> createState() =>
      _StudentRoundTrackerPageState();
}

class _StudentRoundTrackerPageState
    extends ConsumerState<StudentRoundTrackerPage> {
  bool _isLoading = true;
  List<dynamic> _myDrives = [];

  @override
  void initState() {
    super.initState();
    _fetchMyRounds();
  }

  Future<void> _fetchMyRounds() async {
    setState(() => _isLoading = true);
    final repo = ref.read(jobRepositoryProvider);
    final drives = await repo.getMyRounds();

    // Fetch detailed rounds for each drive
    final updatedDrives = await Future.wait(
      drives.map((drive) async {
        final driveId = drive['job_id']?.toString() ?? '';
        if (driveId.isNotEmpty) {
          final rounds = await repo.getDriveRoundsStatus(driveId);
          // Mutable copy so we can insert rounds
          final mutableDrive = Map<String, dynamic>.from(drive);
          mutableDrive['rounds'] = rounds;
          return mutableDrive;
        }
        return drive;
      }),
    );

    if (mounted) {
      setState(() {
        _myDrives = updatedDrives;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Round Tracker'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetchMyRounds,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myDrives.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchMyRounds,
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _myDrives.length,
                itemBuilder: (context, index) {
                  final drive = _myDrives[index];
                  return _buildDriveTrackerCard(drive);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes, size: 80, color: AppColors.border),
          const SizedBox(height: 16),
          const Text(
            'No Active Applications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Apply to jobs to track your progress here.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveTrackerCard(Map<String, dynamic> drive) {
    final rounds = drive['rounds'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(0),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        drive['company_name'] ?? 'Company',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        drive['role_title'] ?? 'Role',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rounds List
          if (rounds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No rounds scheduled yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: rounds.asMap().entries.map((entry) {
                  final index = entry.key;
                  final round = entry.value;
                  final isLast = index == rounds.length - 1;
                  return _buildSquareStepperItem(round, isLast);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSquareStepperItem(Map<String, dynamic> round, bool isLast) {
    final String studentStatus =
        round['my_status']?.toString().toLowerCase() ?? 'pending';
    final String globalStatus =
        round['round_status']?.toString().toLowerCase() ?? 'upcoming';

    // Determine colors based on status
    Color statusColor;
    IconData statusIcon;

    if (studentStatus == 'cleared' ||
        studentStatus == 'shortlisted' ||
        studentStatus == 'selected') {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    } else if (studentStatus == 'rejected') {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel;
    } else if (globalStatus == 'ongoing') {
      statusColor = AppColors.warning;
      statusIcon = Icons.sync;
    } else {
      statusColor = AppColors.textMuted;
      statusIcon = Icons.radio_button_unchecked;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Line & Icon
          Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(0),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Round ${round['round_number']}: ${round['round_name']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                studentStatus == 'pending' &&
                                    globalStatus != 'ongoing'
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          studentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusDescription(globalStatus, studentStatus),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (round['round_mode'] != null ||
                        round['round_datetime'] != null ||
                        round['syllabus'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (round['round_mode'] != null &&
                              round['round_mode'].toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    round['round_mode']
                                            .toString()
                                            .toLowerCase() ==
                                        'online'
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      round['round_mode']
                                              .toString()
                                              .toLowerCase() ==
                                          'online'
                                      ? Colors.green
                                      : Colors.blue,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                round['round_mode'].toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      round['round_mode']
                                              .toString()
                                              .toLowerCase() ==
                                          'online'
                                      ? Colors.green.shade800
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (round['round_datetime'] != null &&
                              round['round_datetime']
                                  .toString()
                                  .isNotEmpty) ...[
                            const Icon(
                              Icons.event_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatDateTime(
                                  round['round_datetime'].toString(),
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (round['syllabus'] != null &&
                          round['syllabus'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Syllabus: ${round['syllabus']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = monthNames[dt.month - 1];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$month ${dt.day}, ${dt.year} • $hour:$min $ampm';
    } catch (_) {
      return isoString;
    }
  }

  String _getStatusDescription(String globalStatus, String studentStatus) {
    if (studentStatus == 'cleared') {
      return 'You have cleared this round! Congratulations.';
    }
    if (studentStatus == 'rejected') {
      return 'Unfortunately, you did not clear this round.';
    }
    if (globalStatus == 'ongoing') {
      return 'This round is currently active/evaluating.';
    }
    if (globalStatus == 'completed') {
      return 'Round completed. Waiting for results.';
    }
    return 'Upcoming round.';
  }
}
