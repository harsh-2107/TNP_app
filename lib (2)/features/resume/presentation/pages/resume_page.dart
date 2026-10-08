import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_row/core/extensions/context_extensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../controllers/resume_controller.dart';

import '../../domain/resume_model.dart';

/// "Upload Resume" screen: drag/browse upload area + a list of resume
/// templates the student can view and use to jump into the Create Resume
/// form.
class ResumePage extends ConsumerWidget {
  const ResumePage({super.key});

  Future<void> _handleUpload(BuildContext context, WidgetRef ref) async {
    try {
      final uploaded = await ref
          .read(resumeControllerProvider.notifier)
          .pickAndUploadResume(
            onConfirm: (fileName) => AppDialog.confirm(
              context,
              title: 'Upload Resume',
              message: 'Are you sure you want to upload "$fileName"?',
              confirmLabel: 'Upload',
            ),
          );
      if (!context.mounted || !uploaded) return;
      context.showSnackBar('Resume uploaded successfully.');
    } catch (e) {
      if (!context.mounted) return;
      final message = ErrorHelper.getPolishedMessage(e);
      AppDialog.showInfo(context, title: 'Upload failed', message: message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeState = ref.watch(resumeControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: AppStrings.uploadResume),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(resumeControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceSuccess,
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_upload_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    AppStrings.choosePdfToUpload,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    AppStrings.uploadHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: AppStrings.browseFiles,
              icon: Icons.folder_open_rounded,
              isLoading: resumeState.isLoading,
              onPressed: resumeState.isLoading
                  ? null
                  : () => _handleUpload(context, ref),
            ),
            const SizedBox(height: 20),
            const Text(
              AppStrings.resumeTemplates,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            resumeState.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => AppErrorView(
                message: ErrorHelper.getPolishedMessage(error),
                onRetry: () =>
                    ref.read(resumeControllerProvider.notifier).refresh(),
              ),
              data: (resumes) => resumes.isEmpty
                  ? const SizedBox.shrink()
                  : _UploadedList(resumes: resumes),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadedList extends StatelessWidget {
  const _UploadedList({required this.resumes});

  final List<StudentFile> resumes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Uploaded Resumes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        for (final resume in resumes)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.borderSm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resume.filename,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
