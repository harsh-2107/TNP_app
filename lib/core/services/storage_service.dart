import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../features/resume/domain/resume_model.dart';
import '../constants/app_config.dart';
import '../network/api_client.dart';

/// Handles three-phase file uploads backed by Supabase Storage.
class StorageService {
  StorageService(this._ref);

  final Ref _ref;

  Future<StudentFile> uploadFile({
    required String userId,
    required String btId,
    required String fileName,
    required Uint8List bytes,
    String fileType = 'resume',
    String? replaceFileId,
  }) async {
    if (bytes.lengthInBytes > AppConfig.maxResumeSizeBytes) {
      throw Exception('File exceeds the size limit.');
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      throw Exception('Only PDF files are supported.');
    }

    final apiClient = _ref.read(apiClientProvider);

    // Phase 1: Request signed upload URL from backend
    final Map<String, dynamic> body = {
      "filename": fileName,
      "mime_type": "application/pdf",
      "size_bytes": bytes.lengthInBytes,
      "file_type": fileType,
      "is_profile_file": true,
    };
    if (replaceFileId != null) {
      body["replace_file_id"] = replaceFileId;
    }

    final phase1Data = await apiClient.post(
      '/storage/upload-url',
      body: body,
    );
    final fileId = phase1Data['file_id'] as String;
    final uploadUrl = phase1Data['upload_url'] as String;

    // Phase 2: Upload raw PDF bytes directly to Supabase Storage signed PUT URL
    final phase2Res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'application/pdf'},
      body: bytes,
    );

    if (phase2Res.statusCode != 200 && phase2Res.statusCode != 201) {
      throw Exception('Failed to upload file to storage bucket.');
    }

    // Phase 3: Notify Backend to finalize upload & auto-rename with BTID
    final phase3Data = await apiClient.post(
      '/storage/complete-upload',
      body: {
        "file_id": fileId,
      },
    );

    return StudentFile.fromJson(phase3Data['file']);
  }

  Future<StudentFile> uploadResume({
    required String userId,
    required String btId,
    required String fileName,
    required Uint8List bytes,
    String? replaceFileId,
  }) {
    return uploadFile(
      userId: userId,
      btId: btId,
      fileName: fileName,
      bytes: bytes,
      fileType: 'resume',
      replaceFileId: replaceFileId,
    );
  }

  Future<StudentFile> uploadCoverLetter({
    required String userId,
    required String btId,
    required String fileName,
    required Uint8List bytes,
  }) {
    return uploadFile(
      userId: userId,
      btId: btId,
      fileName: fileName,
      bytes: bytes,
      fileType: 'cover_letter',
    );
  }

  Future<String?> getFileViewUrl(String fileId) async {
    final apiClient = _ref.read(apiClientProvider);
    final res = await apiClient.get('/storage/files/$fileId/view');
    return res?['download_url'] as String?;
  }

  Future<void> deleteResume(String fileId) async {
    final apiClient = _ref.read(apiClientProvider);
    await apiClient.delete('/storage/files/$fileId');
  }

  Future<void> renameToBtid(String fileId) async {
    final apiClient = _ref.read(apiClientProvider);
    await apiClient.post('/storage/files/$fileId/rename-to-btid');
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref);
});
