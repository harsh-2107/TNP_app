import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/resume_repository.dart';
import '../../domain/resume_model.dart';

class ResumeController extends AsyncNotifier<List<StudentFile>> {
  late ResumeRepository _repository;

  @override
  Future<List<StudentFile>> build() async {
    _repository = ref.watch(resumeRepositoryProvider);
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return [];
    return _repository.fetchResumes(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Opens the native file picker, validates the selection, and uploads
  /// it. Returns true on success so the caller can show a confirmation.
  Future<bool> pickAndUploadResume({
    required Future<bool> Function(String fileName) onConfirm,
    String? replaceFileId,
  }) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return false;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return false;

    final bytes = file.bytes;
    if (bytes == null) return false;

    if (bytes.lengthInBytes > AppConfig.maxResumeSizeBytes) {
      throw const StorageException('File exceeds the 2MB size limit.');
    }

    final shouldUpload = await onConfirm(file.name);
    if (!shouldUpload) return false;

    await _upload(
      userId: user.id,
      fileName: file.name,
      bytes: bytes,
      replaceFileId: replaceFileId,
    );
    return true;
  }

  Future<void> _upload({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? replaceFileId,
  }) async {
    final current = state.value ?? [];
    state = const AsyncLoading<List<StudentFile>>();
    try {
      final resume = await _repository.uploadResume(
        userId: userId,
        fileName: fileName,
        bytes: bytes,
        replaceFileId: replaceFileId,
      );
      final remaining = replaceFileId != null
          ? current.where((f) => f.id != replaceFileId).toList()
          : current;
      state = AsyncData([resume, ...remaining]);
    } catch (e, st) {
      state = AsyncError(ErrorHelper.getPolishedMessage(e), st);
    }
  }

  Future<void> deleteResume(String fileId) async {
    try {
      await _repository.deleteFile(fileId);
      final current = state.value ?? [];
      state = AsyncData(current.where((f) => f.id != fileId).toList());
      await refresh();
    } catch (e, st) {
      state = AsyncError(ErrorHelper.getPolishedMessage(e), st);
    }
  }
}

final resumeControllerProvider =
    AsyncNotifierProvider<ResumeController, List<StudentFile>>(
      ResumeController.new,
    );

class CoverLetterController extends AsyncNotifier<List<StudentFile>> {
  late ResumeRepository _repository;

  @override
  Future<List<StudentFile>> build() async {
    _repository = ref.watch(resumeRepositoryProvider);
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return [];
    return _repository.fetchCoverLetters(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<bool> pickAndUploadCoverLetter({
    required Future<bool> Function(String fileName) onConfirm,
  }) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return false;

    final currentFiles = state.value ?? [];
    if (currentFiles.isNotEmpty) {
      throw const StorageException(
        'Cover letter limit reached. A student may have at most 1 active cover letter in their profile.',
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return false;

    final bytes = file.bytes;
    if (bytes == null) return false;

    if (bytes.lengthInBytes > AppConfig.maxResumeSizeBytes) {
      throw const StorageException('File exceeds the size limit.');
    }

    final shouldUpload = await onConfirm(file.name);
    if (!shouldUpload) return false;

    final current = state.value ?? [];
    state = const AsyncLoading<List<StudentFile>>();
    try {
      final coverLetter = await _repository.uploadCoverLetter(
        userId: user.id,
        fileName: file.name,
        bytes: bytes,
      );
      state = AsyncData([coverLetter, ...current]);
      return true;
    } catch (e, st) {
      state = AsyncError(ErrorHelper.getPolishedMessage(e), st);
      return false;
    }
  }

  Future<void> deleteCoverLetter(String fileId) async {
    try {
      await _repository.deleteFile(fileId);
      final current = state.value ?? [];
      state = AsyncData(current.where((f) => f.id != fileId).toList());
      await refresh();
    } catch (e, st) {
      state = AsyncError(ErrorHelper.getPolishedMessage(e), st);
    }
  }
}

final coverLetterControllerProvider =
    AsyncNotifierProvider<CoverLetterController, List<StudentFile>>(
      CoverLetterController.new,
    );

/// Separate controller for the multi-field "Create New Resume" form so
/// its submit/loading state doesn't interfere with the upload list above.
class CreateResumeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit(ResumeFormData data) async {
    // Backend doesn't support generated resumes yet.
    return false;
  }
}

final createResumeControllerProvider =
    AsyncNotifierProvider<CreateResumeController, void>(
      CreateResumeController.new,
    );
