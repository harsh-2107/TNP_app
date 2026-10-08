import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/errors/error_helper.dart';
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
        title: Text(' Rounds'),
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
                      '',
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
                        round['round_name'] ?? 'Round ',
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
                    if (action == 'edit') {
                      _showRoundFormDialog(existingRound: round);
                    } else if (action == 'delete') {
                      _deleteRound(round['id']);
                    }
                  },
                  itemBuilder: (ctx) => [
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
                  onPressed: () => _uploadCsv(round['id']),
                  icon: const Icon(
                    Icons.upload_file,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Upload CSV',
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
            '',
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
