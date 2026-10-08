import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_row/core/extensions/context_extensions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../data/resume_repository.dart';
import '../controllers/resume_controller.dart';
import '../../domain/resume_model.dart';

/// "Resumes & Cover Letter" screen:
/// - Upload and manage up to 3 resumes (auto-named with student BTID).
/// - Upload and manage 1 cover letter (auto-named with student BTID).
class ResumePage extends ConsumerWidget {
  const ResumePage({super.key});

  Future<void> _handleResumeUpload(BuildContext context, WidgetRef ref) async {
    try {
      final uploaded = await ref
          .read(resumeControllerProvider.notifier)
          .pickAndUploadResume(
            onConfirm: (fileName) => AppDialog.confirm(
              context,
              title: 'Upload Resume',
              message: 'Are you sure you want to upload "$fileName"? It will be auto-named with your BTID.',
              confirmLabel: 'Upload',
            ),
          );
      if (!context.mounted || !uploaded) return;
      context.showSnackBar('Resume uploaded and named with BTID successfully.');
    } catch (e) {
      if (!context.mounted) return;
      final message = ErrorHelper.getPolishedMessage(e);
      AppDialog.showInfo(context, title: 'Upload failed', message: message);
    }
  }

  Future<void> _handleCoverLetterUpload(BuildContext context, WidgetRef ref) async {
    try {
      final uploaded = await ref
          .read(coverLetterControllerProvider.notifier)
          .pickAndUploadCoverLetter(
            onConfirm: (fileName) => AppDialog.confirm(
              context,
              title: 'Upload Cover Letter',
              message: 'Are you sure you want to upload "$fileName" as your cover letter?',
              confirmLabel: 'Upload',
            ),
          );
      if (!context.mounted || !uploaded) return;
      context.showSnackBar('Cover letter uploaded successfully.');
    } catch (e) {
      if (!context.mounted) return;
      final message = ErrorHelper.getPolishedMessage(e);
      AppDialog.showInfo(context, title: 'Upload failed', message: message);
    }
  }

  Future<void> _viewFile(BuildContext context, WidgetRef ref, String fileId) async {
    try {
      final repo = ref.read(resumeRepositoryProvider);
      final downloadUrl = await repo.getFileViewUrl(fileId);
      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (context.mounted) {
        context.showSnackBar('Could not open preview for this file.');
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(ErrorHelper.getPolishedMessage(e));
      }
    }
  }

  Future<void> _deleteResume(BuildContext context, WidgetRef ref, StudentFile file) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete Resume?',
      message: 'Are you sure you want to remove "${file.filename}" from your profile?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    await ref.read(resumeControllerProvider.notifier).deleteResume(file.id);
    if (context.mounted) {
      context.showSnackBar('Resume removed successfully.');
    }
  }

  Future<void> _deleteCoverLetter(BuildContext context, WidgetRef ref, StudentFile file) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete Cover Letter?',
      message: 'Are you sure you want to remove "${file.filename}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    await ref.read(coverLetterControllerProvider.notifier).deleteCoverLetter(file.id);
    if (context.mounted) {
      context.showSnackBar('Cover letter removed successfully.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeState = ref.watch(resumeControllerProvider);
    final coverLetterState = ref.watch(coverLetterControllerProvider);

    final resumeCount = resumeState.value?.length ?? 0;
    final isResumeLimitReached = resumeCount >= 3;

    final coverLetters = coverLetterState.value ?? [];
    final hasCoverLetter = coverLetters.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Resumes & Documents'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(resumeControllerProvider.notifier).refresh();
          await ref.read(coverLetterControllerProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ================= RESUMES SECTION =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Resumes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isResumeLimitReached
                        ? AppColors.surfaceError
                        : AppColors.surfaceSuccess,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Text(
                    '$resumeCount / 3 Uploaded',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isResumeLimitReached
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (!isResumeLimitReached) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSuccess,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose PDF to upload',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PDF format only, maximum 5 MB. Auto-named with BTID.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Browse & Upload Resume',
                icon: Icons.folder_open_rounded,
                isLoading: resumeState.isLoading,
                onPressed: resumeState.isLoading
                    ? null
                    : () => _handleResumeUpload(context, ref),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceError,
                  borderRadius: AppRadius.borderSm,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.error),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Maximum limit of 3 profile resumes reached. Delete one to upload a new resume.',
                        style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Resumes list
            resumeState.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
              error: (error, _) => AppErrorView(
                message: ErrorHelper.getPolishedMessage(error),
                onRetry: () => ref.read(resumeControllerProvider.notifier).refresh(),
              ),
              data: (resumes) {
                if (resumes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No resumes uploaded yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  );
                }
                return Column(
                  children: [
                    for (final resume in resumes)
                      _FileCard(
                        file: resume,
                        onView: () => _viewFile(context, ref, resume.id),
                        onDelete: () => _deleteResume(context, ref, resume),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),

            // ================= COVER LETTER SECTION =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cover Letter',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasCoverLetter
                        ? AppColors.surfaceSuccess
                        : AppColors.surface,
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    hasCoverLetter ? '1 / 1 Uploaded' : '0 / 1 Uploaded',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasCoverLetter
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (!hasCoverLetter) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'No cover letter uploaded',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload your professional cover letter in PDF format (Max 1).',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Upload Cover Letter',
                icon: Icons.upload_file_rounded,
                isLoading: coverLetterState.isLoading,
                onPressed: coverLetterState.isLoading
                    ? null
                    : () => _handleCoverLetterUpload(context, ref),
              ),
            ] else ...[
              coverLetterState.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                error: (error, _) => AppErrorView(
                  message: ErrorHelper.getPolishedMessage(error),
                  onRetry: () => ref.read(coverLetterControllerProvider.notifier).refresh(),
                ),
                data: (letters) {
                  if (letters.isEmpty) return const SizedBox.shrink();
                  final letter = letters.first;
                  return _FileCard(
                    file: letter,
                    isCoverLetter: true,
                    onView: () => _viewFile(context, ref, letter.id),
                    onDelete: () => _deleteCoverLetter(context, ref, letter),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    this.isCoverLetter = false,
    required this.onView,
    required this.onDelete,
  });

  final StudentFile file;
  final bool isCoverLetter;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.borderSm,
      ),
      child: Row(
        children: [
          Icon(
            isCoverLetter ? Icons.description_rounded : Icons.picture_as_pdf_rounded,
            size: 22,
            color: isCoverLetter ? AppColors.primary : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.filename,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isCoverLetter ? 'Cover Letter • PDF' : 'Resume • PDF',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View Document',
            icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.primary),
            onPressed: onView,
          ),
          IconButton(
            tooltip: 'Delete Document',
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
