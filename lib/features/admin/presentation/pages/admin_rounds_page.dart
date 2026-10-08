import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../data/admin_repository.dart';

class AdminRoundsPage extends ConsumerStatefulWidget {
  final String driveId;
  final String companyName;

  const AdminRoundsPage({
    super.key,
    required this.driveId,
    required this.companyName,
  });

  @override
  ConsumerState<AdminRoundsPage> createState() => _AdminRoundsPageState();
}

class _AdminRoundsPageState extends ConsumerState<AdminRoundsPage> {
  bool _isLoading = true;
  List<dynamic> _rounds = [];

  @override
  void initState() {
    super.initState();
    _fetchRounds();
  }

  Future<void> _fetchRounds() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final rounds = await repo.getDriveRounds(widget.driveId);
      rounds.sort(
        (a, b) =>
            (a['round_number'] as int).compareTo(b['round_number'] as int),
      );
      if (mounted) {
        setState(() {
          _rounds = rounds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteRound(String roundId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Round'),
        content: const Text(
          'Are you sure you want to delete this round? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.deleteDriveRound(widget.driveId, roundId);
      await _fetchRounds();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Round deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    }
  }

  Future<void> _sendRoundReminders(String roundId, String roundName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Round Reminders'),
        content: Text(
          'Do you want to dispatch reminder emails and in-app notifications for "$roundName" to all eligible candidates?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Reminders'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.sendRoundReminders(widget.driveId, roundId);
      final count = res['candidates_notified'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminders dispatched to $count eligible candidates.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getPolishedMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showRoundResultsModal(Map<String, dynamic> round) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _RoundResultsModal(
        driveId: widget.driveId,
        round: round,
        onResultsUpdated: () => _fetchRounds(),
      ),
    );
  }

  Future<void> _uploadCsv(String roundId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final fileData = result.files.first.bytes;
      if (fileData == null) return;

      final csvString = utf8.decode(fileData);

      try {
        final repo = ref.read(adminRepositoryProvider);
        await repo.bulkUploadRoundStatus(widget.driveId, roundId, csvString);
        await _fetchRounds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV uploaded! Candidate stats refreshed.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
          );
        }
      }
    }
  }

  void _showRoundFormDialog({Map<String, dynamic>? existingRound}) {
    final isEdit = existingRound != null;
    final formKey = GlobalKey<FormState>();

    final nameCtrl = TextEditingController(
      text: existingRound?['round_name'] ?? '',
    );
    final typeCtrl = TextEditingController(
      text: existingRound?['round_type'] ?? '',
    );

    String roundMode = existingRound?['round_mode'] ?? 'Online';
    String roundStatus = existingRound?['status'] ?? 'upcoming';
    DateTime? roundDatetime;

    final existingDt = existingRound?['round_datetime'];
    if (existingDt != null && existingDt.toString().isNotEmpty) {
      try {
        roundDatetime = DateTime.parse(existingDt.toString()).toLocal();
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isEdit ? 'Edit Round' : 'Add New Round',
                style: const TextStyle(color: AppColors.primary),
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Round Name *',
                            hintText:
                                'e.g. Online Assessment, Tech Interview, HR',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: typeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Round Type *',
                            hintText: 'e.g. aptitude, coding, technical, hr',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: roundMode,
                          decoration: const InputDecoration(
                            labelText: 'Mode',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Online',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.wifi,
                                    size: 16,
                                    color: AppColors.info,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Online'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Offline',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: AppColors.warning,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Offline'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => roundMode = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: roundStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'upcoming',
                              child: Text('Upcoming'),
                            ),
                            DropdownMenuItem(
                              value: 'ongoing',
                              child: Text('Ongoing'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Completed'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => roundStatus = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: roundDatetime ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 3),
                            );
                            if (date == null) return;
                            if (!ctx.mounted) return;
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(
                                roundDatetime ?? now,
                              ),
                            );
                            if (time == null) return;
                            setDialogState(() {
                              roundDatetime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderStrong),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    roundDatetime != null
                                        ? DateFormat(
                                            'EEE, dd MMM yyyy  hh:mm a',
                                          ).format(roundDatetime!)
                                        : 'Pick Date & Time (optional)',
                                    style: TextStyle(
                                      color: roundDatetime != null
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                if (roundDatetime != null)
                                  GestureDetector(
                                    onTap: () => setDialogState(
                                      () => roundDatetime = null,
                                    ),
                                    child: const Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final payload = <String, dynamic>{
                      'round_name': nameCtrl.text.trim(),
                      'round_type': typeCtrl.text.trim(),
                      'round_mode': roundMode,
                      'status': roundStatus,
                    };

                    if (!isEdit) payload['round_number'] = _rounds.length + 1;

                    if (roundDatetime != null) {
                      payload['round_datetime'] = roundDatetime!
                          .toUtc()
                          .toIso8601String();
                    }

                    try {
                      final repo = ref.read(adminRepositoryProvider);
                      if (isEdit) {
                        await repo.updateDriveRound(
                          widget.driveId,
                          existingRound['id'],
                          payload,
                        );
                      } else {
                        await repo.createDriveRound(widget.driveId, payload);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _fetchRounds();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit ? 'Round updated!' : 'Round created!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e, t) {
                      print(e);
                      print(t);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ErrorHelper.getPolishedMessage(e)),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(isEdit ? 'Update Round' : 'Create Round'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Rounds'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRounds,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showRoundFormDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Round', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rounds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.assessment_outlined,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No rounds defined yet.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add the first round.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchRounds,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _rounds.length,
                itemBuilder: (context, index) =>
                    _buildRoundCard(_rounds[index], index),
              ),
            ),
    );
  }

  Widget _buildRoundCard(Map<String, dynamic> round, int index) {
    final status = (round['status'] ?? 'upcoming').toString().toLowerCase();
    final mode = (round['round_mode'] ?? 'Online').toString();
    final dt = round['round_datetime'];
    final stats = round['candidate_stats'] as Map<String, dynamic>? ?? {};
    final total = (stats['total'] as num?)?.toInt() ?? 0;
    final shortlisted = (stats['shortlisted'] as num?)?.toInt() ?? 0;
    final rejected = (stats['rejected'] as num?)?.toInt() ?? 0;
    final selected = (stats['selected'] as num?)?.toInt() ?? 0;

    final (statusColor, statusBg) = _statusColors(status);
    final modeColor = mode == 'Offline' ? AppColors.warning : AppColors.info;

    String? formattedDt;
    if (dt != null && dt.toString().isNotEmpty) {
      try {
        formattedDt = DateFormat(
          'EEE, dd MMM yyyy  hh:mm a',
        ).format(DateTime.parse(dt.toString()).toLocal());
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(0),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${round['round_number'] ?? (index + 1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        round['round_name'] ?? 'Round ${round['round_number'] ?? (index + 1)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        round['round_type']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    if (action == 'upload_results') {
                      _showRoundResultsModal(round);
                    } else if (action == 'edit') {
                      _showRoundFormDialog(existingRound: round);
                    } else if (action == 'delete') {
                      _deleteRound(round['id']);
                    } else if (action == 'remind') {
                      _sendRoundReminders(
                        round['id'],
                        round['round_name'] ?? 'Round ${round['round_number']}',
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'upload_results',
                      child: Row(
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 16,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 8),
                          Text('Upload Results'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Round'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remind',
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text('Send Reminders'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Round',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildBadge(status.toUpperCase(), statusColor, bg: statusBg),
                _buildBadge(mode, modeColor),
                if (formattedDt != null)
                  _buildBadge(
                    formattedDt,
                    AppColors.textSecondary,
                    icon: Icons.calendar_today,
                  ),
              ],
            ),
          ),

          // Candidate stats
          if (total > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*
                  const Text(
                    'Candidate Stats',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatPill('Total', total, AppColors.info),
                      const SizedBox(width: 8),
                      _buildStatPill(
                        'Shortlisted',
                        shortlisted,
                        AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _buildStatPill('Selected', selected, AppColors.success),
                      const SizedBox(width: 8),
                      _buildStatPill('Rejected', rejected, AppColors.error),

                      
                    ],
                  ),
                  */
                ],
              ),
            ),
          ],

          // CSV Uploader
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk CSV Upload',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Required columns: bt_id, status',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Values: shortlisted | selected | rejected | absent',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showRoundResultsModal(round),
                  icon: const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Update Results',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'ongoing':
        return (AppColors.warning, AppColors.warning.withValues(alpha: 0.1));
      case 'completed':
        return (AppColors.success, AppColors.success.withValues(alpha: 0.1));
      default:
        return (AppColors.info, AppColors.info.withValues(alpha: 0.1));
    }
  }

  Widget _buildBadge(String text, Color color, {Color? bg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundResultsModal extends ConsumerStatefulWidget {
  const _RoundResultsModal({
    required this.driveId,
    required this.round,
    required this.onResultsUpdated,
  });

  final String driveId;
  final Map<String, dynamic> round;
  final VoidCallback onResultsUpdated;

  @override
  ConsumerState<_RoundResultsModal> createState() => _RoundResultsModalState();
}

class _RoundResultsModalState extends ConsumerState<_RoundResultsModal> {
  bool _isLoading = true;
  bool _isUploadingCsv = false;
  String? _updatingStudentId;
  List<dynamic> _candidates = [];
  String _searchQuery = '';
  String _statusFilter = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCandidates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCandidates() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final cands = await repo.getRoundCandidates(
        widget.driveId,
        widget.round['id'],
      );
      if (mounted) {
        setState(() {
          _candidates = cands;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load candidates: ${ErrorHelper.getPolishedMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final token = supabase.auth.currentSession?.accessToken;
      final repo = ref.read(adminRepositoryProvider);
      final uri = repo.getRoundCandidatesCsvTemplateUri(
        widget.driveId,
        widget.round['id'],
        token: token,
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloading pre-filled candidates CSV template...'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        throw Exception('Could not launch download URL: $uri');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error downloading template: ${ErrorHelper.getPolishedMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to read CSV file data.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final csvString = utf8.decode(fileBytes);

    setState(() => _isUploadingCsv = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.bulkUploadRoundStatus(
        widget.driveId,
        widget.round['id'],
        csvString,
      );

      final summary = res['summary'] as Map<String, dynamic>?;
      final updatedCount = summary?['matched_and_updated'] ?? 0;
      final totalParsed = summary?['total_rows_parsed'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$updatedCount candidates updated successfully! ($totalParsed rows processed)',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      await _fetchCandidates();
      widget.onResultsUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getPolishedMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCsv = false);
    }
  }

  Future<void> _updateCandidateStatus(
    String studentId,
    String studentName,
    String newStatus,
  ) async {
    setState(() => _updatingStudentId = studentId);
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateRoundCandidateStatus(
        widget.driveId,
        widget.round['id'],
        studentId,
        status: newStatus,
      );

      if (mounted) {
        setState(() {
          final idx = _candidates.indexWhere((c) => c['student_id'] == studentId);
          if (idx != -1) {
            _candidates[idx]['status'] = newStatus;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'selected'
                  ? '$studentName approved (Selected for next round)!'
                  : '$studentName marked as ${newStatus.toUpperCase()}.',
            ),
            backgroundColor:
                newStatus == 'selected' ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      widget.onResultsUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getPolishedMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStudentId = null);
    }
  }

  List<dynamic> get _filteredCandidates {
    return _candidates.where((c) {
      final status = (c['status'] ?? 'pending').toString().toLowerCase();
      if (_statusFilter != 'all') {
        if (_statusFilter == 'selected' &&
            status != 'selected' &&
            status != 'shortlisted') {
          return false;
        }
        if (_statusFilter == 'rejected' && status != 'rejected') {
          return false;
        }
        if (_statusFilter == 'pending' && status != 'pending') {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (c['full_name'] ?? '').toString().toLowerCase();
        final btId = (c['bt_id'] ?? '').toString().toLowerCase();
        final email = (c['email'] ?? '').toString().toLowerCase();
        final branch = (c['branch'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            btId.contains(q) ||
            email.contains(q) ||
            branch.contains(q);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: mediaQuery.size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: AppColors.success,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upload Results & Candidate Qualification',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.round['round_name'] ?? 'Round'} • Mode: ${widget.round['round_mode'] ?? 'Online'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. CSV Uploader Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.table_chart_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bulk CSV Results Upload',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_isUploadingCsv)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Accepted Columns: bt_id (or email), status (Selected / Shortlisted / Rejected / Absent), remarks (optional)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _downloadTemplate,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download Candidates Template'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isUploadingCsv ? null : _uploadCsv,
                          icon: const Icon(
                            Icons.upload_file_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isUploadingCsv
                                ? 'Uploading...'
                                : 'Upload Results CSV',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Search and Status Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search by student name, BT ID, branch...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh candidate list',
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchCandidates,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', _candidates.length),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'Selected',
                      'selected',
                      _candidates
                          .where((c) =>
                              c['status'] == 'selected' ||
                              c['status'] == 'shortlisted')
                          .length,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'Pending',
                      'pending',
                      _candidates.where((c) => c['status'] == 'pending').length,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      'Rejected',
                      'rejected',
                      _candidates.where((c) => c['status'] == 'rejected').length,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. Candidates Roster
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredCandidates.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching candidates for "$_searchQuery"'
                                      : 'No candidates registered for this round yet.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredCandidates.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final candidate = _filteredCandidates[index];
                              return _buildCandidateRow(candidate);
                            },
                          ),
              ),

              const SizedBox(height: 12),

              // Close / Done button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text('$label ($count)', style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
    );
  }

  Widget _buildCandidateRow(Map<String, dynamic> candidate) {
    final studentId = candidate['student_id']?.toString() ?? '';
    final fullName = candidate['full_name']?.toString() ?? 'N/A';
    final btId = candidate['bt_id']?.toString() ?? 'N/A';
    final branch = candidate['branch']?.toString() ?? '';
    final cgpa = candidate['cgpa'];
    final status = (candidate['status'] ?? 'pending').toString().toLowerCase();

    final isUpdating = _updatingStudentId == studentId;
    final isSelected = status == 'selected' || status == 'shortlisted';
    final isRejected = status == 'rejected';

    Color statusBadgeColor = AppColors.textSecondary;
    Color statusBadgeBg = AppColors.surfaceMuted;
    if (isSelected) {
      statusBadgeColor = AppColors.success;
      statusBadgeBg = AppColors.success.withOpacity(0.12);
    } else if (isRejected) {
      statusBadgeColor = AppColors.error;
      statusBadgeBg = AppColors.error.withOpacity(0.12);
    } else if (status == 'absent') {
      statusBadgeColor = Colors.orange;
      statusBadgeBg = Colors.orange.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.success.withOpacity(0.4)
              : isRejected
                  ? AppColors.error.withOpacity(0.4)
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Student details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusBadgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusBadgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$btId${branch.isNotEmpty ? ' • $branch' : ''}${cgpa != null ? ' • CGPA: $cgpa' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Tick sign (Approve) & Wrong sign (Reject) buttons
          if (isUpdating)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tick button (Approve / Select)
                InkWell(
                  onTap: () => _updateCandidateStatus(studentId, fullName, 'selected'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.success
                          : AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Wrong button (Reject)
                InkWell(
                  onTap: () => _updateCandidateStatus(studentId, fullName, 'rejected'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? AppColors.error
                          : AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.error,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isRejected ? Colors.white : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

