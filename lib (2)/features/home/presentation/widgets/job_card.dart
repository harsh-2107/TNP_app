import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../domain/job_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../resume/data/resume_repository.dart';
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

      String? resumeId;
      if (resumes.isNotEmpty) {
        resumeId = resumes
            .firstWhere((r) => r.isDefault, orElse: () => resumes.first)
            .id;
      }

      await ref
          .read(jobRepositoryProvider)
          .applyToJob(
            studentId: user.id,
            jobId: widget.job.id,
            resumeFileId: resumeId,
            customFields: customFields,
          );

      ref.invalidate(homeControllerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully!')),
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: AppCardTone.success,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.job.isJob
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.job.isJob ? 'JOB' : 'INTERN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.job.isJob
                                  ? AppColors.primary
                                  : Colors.orange.shade800,
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
            child: _isExpanded && widget.job.rawCsvData.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
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
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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

