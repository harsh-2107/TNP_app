import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../domain/resume_model.dart';

class ResumeRepository {
  ResumeRepository(this._ref);

  final Ref _ref;

  Future<List<StudentFile>> fetchResumes(String userId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/storage/profile/files');
    if (response != null && response['files'] != null) {
      final List files = response['files'];
      return files
          .map((row) => StudentFile.fromJson(row as Map<String, dynamic>))
          .where((f) => f.fileType == 'resume')
          .toList();
    }
    return [];
  }

  Future<List<StudentFile>> fetchCoverLetters(String userId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/storage/profile/files');
    if (response != null && response['files'] != null) {
      final List files = response['files'];
      return files
          .map((row) => StudentFile.fromJson(row as Map<String, dynamic>))
          .where((f) => f.fileType == 'cover_letter')
          .toList();
    }
    return [];
  }

  Future<StudentFile> uploadResume({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? replaceFileId,
  }) async {
    final client = _ref.read(apiClientProvider);
    final profile = await client.get('/api/students/profile');
    final btId = profile['profile']['bt_id'] as String;

    final storageService = _ref.read(storageServiceProvider);
    final file = await storageService.uploadResume(
      userId: userId,
      btId: btId,
      fileName: fileName,
      bytes: bytes,
      replaceFileId: replaceFileId,
    );
    return file;
  }

  Future<StudentFile> uploadCoverLetter({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final client = _ref.read(apiClientProvider);
    final profile = await client.get('/api/students/profile');
    final btId = profile['profile']['bt_id'] as String;

    final storageService = _ref.read(storageServiceProvider);
    final file = await storageService.uploadCoverLetter(userId: userId, btId: btId, fileName: fileName, bytes: bytes);
    return file;
  }

  Future<void> deleteFile(String fileId) async {
    final storageService = _ref.read(storageServiceProvider);
    await storageService.deleteResume(fileId);
  }

  Future<String?> getFileViewUrl(String fileId) async {
    final storageService = _ref.read(storageServiceProvider);
    return storageService.getFileViewUrl(fileId);
  }

  // Future<void> createResume(ResumeFormData data, String userId) async {
  //   final client = _ref.read(supabaseClientProvider);
  //   await client.from('generated_resumes').insert(data.toJson(userId));
  // }
}

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) => ResumeRepository(ref));
