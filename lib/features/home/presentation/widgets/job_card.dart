import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/job_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../resume/data/resume_repository.dart';
import '../../../resume/domain/resume_model.dart';
import '../../data/job_repository.dart';
import '../controllers/home_controller.dart';

class JobCard extends ConsumerStatefulWidget {
  const JobCard({super.key, required this.job, this.onTap});

  final CompanyDrive job;
  final VoidCallback? onTap;

  @override
  ConsumerState<JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<JobCard> {
  bool _isExpanded = false;
  bool _isApplying = false;
  bool _isRejecting = false;

  Future<void> _reject() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Opportunity?'),
        content: const Text(
          'Are you sure you want to reject this job? It will be permanently removed from your feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRejecting = true);
    try {
      final user = ref.read(authControllerProvider).value;
      if (user == null) throw Exception('You must be logged in to reject.');

      await ref
          .read(jobRepositoryProvider)
          .rejectJob(studentId: user.id, jobId: widget.job.id);

      ref.invalidate(homeControllerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job rejected and removed from feed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      final user = ref.read(authControllerProvider).value;
      if (user == null) throw Exception('You must be logged in to apply.');

      // 1. Pre-apply checker: check baseline eligibility and custom required fields
      final requirements = await ref.read(jobRepositoryProvider).checkDriveRequirements(
        jobId: widget.job.id,
        studentId: user.id,
      );

      if (requirements['is_primary_eligible'] == false) {
        final reasons = requirements['reasons'] as List?;
        final reasonText = (reasons != null && reasons.isNotEmpty)
            ? reasons.join(', ')
            : 'You do not meet the baseline eligibility criteria for this drive.';
        throw Exception(reasonText);
      }

      Map<String, dynamic>? customFields;
      if (requirements['requires_additional_info'] == true) {
        final List missing = requirements['missing_fields'] ?? [];
        if (missing.isNotEmpty && mounted) {
          setState(() => _isApplying = false);
          customFields = await _showCustomRequirementsDialog(context, missing);
          if (customFields == null) {
            // Student dismissed/cancelled input prompt
            return;
          }
          if (mounted) setState(() => _isApplying = true);
        }
      }

      final resumes = await ref
          .read(resumeRepositoryProvider)
          .fetchResumes(user.id);

      if (!mounted) return;
      setState(() => _isApplying = false);

      final selectedResume = await showDialog<StudentFile>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => _ResumeSelectionDialog(
          job: widget.job,
          initialResumes: resumes,
          userId: user.id,
        ),
      );

      if (selectedResume == null) {
        // User cancelled dialog
        return;
      }

      if (mounted) setState(() => _isApplying = true);

      await ref
          .read(jobRepositoryProvider)
          .applyToJob(
            studentId: user.id,
            jobId: widget.job.id,
            resumeFileId: selectedResume.id,
            customFields: customFields,
          );

      ref.invalidate(homeControllerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Application submitted successfully with "${selectedResume.filename}"!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<Map<String, dynamic>?> _showCustomRequirementsDialog(
    BuildContext context,
    List missing,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _CustomRequirementsDialog(
          job: widget.job,
          missing: missing,
        );
      },
    );
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: AppCardTone.neutral,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        if (widget.onTap != null) widget.onTap!();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.job.roleTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: widget.job.isJob
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.job.isJob ? 'JOB' : 'INTERN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.job.isJob
                                  ? AppColors.primary
                                  : AppColors.secondary,
                            ),
                          ),
                        ),
                        if (widget.job.hasApplied) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.job.companyName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppChip(
                      label: widget.job.status.toUpperCase(),
                      icon: widget.job.status == 'open'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      tone: widget.job.status == 'open'
                          ? AppChipTone.success
                          : AppChipTone.neutral,
                    ),
                  ],
                ),
              ),
              Icon(
                _isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),

                      // Package details if available directly
                      if (widget.job.expectedPackage.isNotEmpty &&
                          widget.job.expectedPackage != 'N/A') ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Package: ${widget.job.expectedPackage}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Description / Overview if available
                      if (widget.job.jobDescription.isNotEmpty &&
                          widget.job.jobDescription != 'N/A') ...[
                        Text(
                          widget.job.jobDescription,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Structured Description Sections (ExpansionTile accordions)
                      if (widget.job.descriptionSections.isNotEmpty) ...[
                        ...widget.job.descriptionSections.map((sec) {
                          final heading =
                              (sec['heading'] ?? 'Details').toString();
                          final content = (sec['content'] ?? '').toString();
                          final subfields =
                              (sec['subfields'] as List<dynamic>?) ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                dense: true,
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                title: Text(
                                  heading,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  10,
                                ),
                                children: [
                                  if (content.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        content,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  if (subfields.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: subfields.map((sf) {
                                        final lbl =
                                            (sf['label'] ?? '').toString();
                                        final val =
                                            (sf['value'] ?? '').toString();
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$lbl: $val',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],

                      // Selection Rounds Section (Mode badge, scheduled Date & Time, Syllabus)
                      if (widget.job.rounds.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Selection Rounds',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.job.rounds.asMap().entries.map((rEntry) {
                          final idx = rEntry.key;
                          final round = rEntry.value;
                          final rNum = round['round_number'] ?? (idx + 1);
                          final rName =
                              (round['round_name'] ?? 'Round $rNum').toString();
                          final rMode =
                              (round['round_mode'] ?? 'Online').toString();
                          final isOnline = rMode.toLowerCase() == 'online';
                          final rDateTime = round['round_datetime']?.toString();
                          final syllabus = (round['syllabus'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Round $rNum: $rName',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? Colors.green.shade50
                                            : Colors.blue.shade50,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isOnline
                                              ? Colors.green
                                              : Colors.blue,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isOnline
                                                ? Icons.wifi
                                                : Icons.location_on_outlined,
                                            size: 11,
                                            color: isOnline
                                                ? Colors.green.shade800
                                                : Colors.blue.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            rMode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isOnline
                                                  ? Colors.green.shade800
                                                  : Colors.blue.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (rDateTime != null &&
                                    rDateTime.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.event_outlined,
                                        size: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDateTime(rDateTime),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (syllabus.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.menu_book_outlined,
                                        size: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Syllabus: $syllabus',
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
                            ),
                          );
                        }),
                      ],

                      // Additional / Legacy Metadata from rawCsvData
                      if (widget.job.rawCsvData.isNotEmpty) ...[
                        ...widget.job.rawCsvData.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatKey(entry.key),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 16),
                      if (widget.job.hasApplied)
                        const SizedBox(
                          width: double.infinity,
                          child: Text(
                            'You have already applied for this position.',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isApplying || _isRejecting
                                ? null
                                : _apply,
                            child: _isApplying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Apply'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          onPressed: _isApplying || _isRejecting
                              ? null
                              : _reject,
                          child: _isRejecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.error,
                                  ),
                                )
                              : const Text('Reject Opportunity'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CustomRequirementsDialog extends StatefulWidget {
  final CompanyDrive job;
  final List missing;

  const _CustomRequirementsDialog({
    required this.job,
    required this.missing,
  });

  @override
  State<_CustomRequirementsDialog> createState() => _CustomRequirementsDialogState();
}

class _CustomRequirementsDialogState extends State<_CustomRequirementsDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.missing) {
      _controllers[item['field'].toString()] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Additional Details Required',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.job.companyName} requires the following details for your application:',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            for (final item in widget.missing) ...[
              Text(
                item['label']?.toString() ?? item['field'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controllers[item['field'].toString()],
                keyboardType: item['type'] == 'number'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Enter your ${item['label'] ?? item['field']}',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final values = <String, dynamic>{};
            for (final item in widget.missing) {
              final field = item['field'].toString();
              final text = _controllers[field]?.text.trim() ?? '';
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter ${item['label'] ?? field}'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              if (item['type'] == 'number') {
                values[field] = num.tryParse(text) ?? text;
              } else {
                values[field] = text;
              }
            }
            Navigator.of(context).pop(values);
          },
          child: const Text('Submit & Apply'),
        ),
      ],
    );
  }
}

class _ResumeSelectionDialog extends ConsumerStatefulWidget {
  const _ResumeSelectionDialog({
    required this.job,
    required this.initialResumes,
    required this.userId,
  });

  final CompanyDrive job;
  final List<StudentFile> initialResumes;
  final String userId;

  @override
  ConsumerState<_ResumeSelectionDialog> createState() =>
      _ResumeSelectionDialogState();
}

class _ResumeSelectionDialogState
    extends ConsumerState<_ResumeSelectionDialog> {
  late List<StudentFile> _resumes;
  StudentFile? _selectedResume;
  bool _isUploading = false;
  String? _uploadStatusText;

  @override
  void initState() {
    super.initState();
    _resumes = List.from(widget.initialResumes);
    if (_resumes.isNotEmpty) {
      _selectedResume = _resumes.firstWhere(
        (r) => r.isDefault,
        orElse: () => _resumes.first,
      );
    }
  }

  Future<void> _handleUploadNewResume() async {
    if (_resumes.length >= 3) {
      await _showLimitReachedPrompt();
    } else {
      await _pickAndUpload(replaceFileId: null);
    }
  }

  Future<void> _showLimitReachedPrompt() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resume Limit Reached (3/3)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Maximum of 3 profile resumes allowed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'To upload a new resume on the go, choose which existing resume to replace, or delete one from your profile:',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  tileColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  leading: const Icon(
                    Icons.sync_alt_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Choose Resume to Replace',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Select one of your 3 resumes to overwrite',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showChooseToReplaceDialog();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  tileColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Delete a Resume',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Remove an existing resume to free up a slot',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showDeleteResumeDialog();
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChooseToReplaceDialog() async {
    final StudentFile? targetToReplace = await showDialog<StudentFile>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Select Resume to Replace',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const Text(
                'The selected resume will be replaced with your new upload:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              for (final r in _resumes) ...[
                ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    r.filename,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: r.isDefault
                      ? const Text(
                          'Default Resume',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        )
                      : null,
                  trailing: const Icon(Icons.file_upload_outlined, size: 20),
                  onTap: () => Navigator.of(dialogCtx).pop(r),
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (targetToReplace == null) return;
    await _pickAndUpload(replaceFileId: targetToReplace.id);
  }

  Future<void> _showDeleteResumeDialog() async {
    final StudentFile? targetToDelete = await showDialog<StudentFile>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Select Resume to Delete',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select a resume to remove from your profile:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                for (final r in _resumes) ...[
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.error,
                    ),
                    title: Text(
                      r.filename,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: r.isDefault
                        ? const Text(
                            'Default Resume',
                            style: TextStyle(color: Colors.green, fontSize: 11),
                          )
                        : null,
                    trailing: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onTap: () => Navigator.of(dialogCtx).pop(r),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (targetToDelete == null) return;

    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete "${targetToDelete.filename}"?',
      message:
          'This will remove the resume from your profile and free up a slot.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed) return;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Deleting resume...';
    });

    try {
      await ref.read(resumeRepositoryProvider).deleteFile(targetToDelete.id);
      setState(() {
        _resumes.removeWhere((r) => r.id == targetToDelete.id);
        if (_selectedResume?.id == targetToDelete.id) {
          _selectedResume = _resumes.isNotEmpty ? _resumes.first : null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Resume deleted. Slot available to upload a new resume!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting resume: ${ErrorHelper.getPolishedMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  Future<void> _pickAndUpload({required String? replaceFileId}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );

      final file = result?.files.single;
      if (file == null) return;

      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Could not read file data. Please try another file.');
      }

      if (bytes.lengthInBytes > AppConfig.maxResumeSizeBytes) {
        throw Exception('File size exceeds the 2MB limit.');
      }

      setState(() {
        _isUploading = true;
        _uploadStatusText = replaceFileId != null
            ? 'Replacing resume...'
            : 'Uploading resume...';
      });

      final uploadedFile = await ref
          .read(resumeRepositoryProvider)
          .uploadResume(
            userId: widget.userId,
            fileName: file.name,
            bytes: bytes,
            replaceFileId: replaceFileId,
          );

      setState(() {
        if (replaceFileId != null) {
          final idx = _resumes.indexWhere((r) => r.id == replaceFileId);
          if (idx != -1) {
            _resumes[idx] = uploadedFile;
          } else {
            _resumes.add(uploadedFile);
          }
        } else {
          _resumes.add(uploadedFile);
        }
        _selectedResume = uploadedFile;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replaceFileId != null
                  ? 'Resume replaced successfully!'
                  : 'Resume uploaded successfully!',
            ),
            backgroundColor: AppColors.success,
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
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Resume to Apply',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.job.companyName} • ${widget.job.roleTitle}',
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
                    onPressed: () => Navigator.of(context).pop(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quota / helper banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _resumes.length >= 3
                      ? Colors.amber.withOpacity(0.1)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _resumes.length >= 3
                        ? Colors.amber.shade300
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _resumes.length >= 3
                          ? Icons.info_outline
                          : Icons.cloud_done_outlined,
                      size: 16,
                      color: _resumes.length >= 3
                          ? Colors.orange.shade800
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resumes.length >= 3
                            ? 'Profile resumes: 3/3 (Max limit reached)'
                            : 'Profile resumes: ${_resumes.length}/3 available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _resumes.length >= 3
                              ? Colors.orange.shade900
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Resumes List
              if (_resumes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.upload_file, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No resumes found on your profile',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Please upload a resume below to proceed with your application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final resume in _resumes) ...[
                      _buildResumeTile(resume),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              const SizedBox(height: 12),
              // Upload Button
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _uploadStatusText ?? 'Processing...',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _handleUploadNewResume,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _resumes.length >= 3
                        ? '+ Upload / Replace Resume'
                        : '+ Upload New Resume',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              // Bottom Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedResume != null && !_isUploading)
                          ? () => Navigator.of(context).pop(_selectedResume)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Apply with Selected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeTile(StudentFile resume) {
    final isSelected = _selectedResume?.id == resume.id;
    return InkWell(
      onTap: () => setState(() => _selectedResume = resume),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: resume.id,
              groupValue: _selectedResume?.id,
              activeColor: AppColors.primary,
              onChanged: (_) => setState(() => _selectedResume = resume),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resume.filename,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (resume.isDefault)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

