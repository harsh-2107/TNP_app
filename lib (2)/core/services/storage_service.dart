import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../features/resume/domain/resume_model.dart';
import '../constants/app_config.dart';
import '../network/api_client.dart';

/// Handles two-phase file uploads to the backend.
class StorageService {
  StorageService(this._ref);

  final Ref _ref;

  Future<StudentFile> uploadResume({
    required String userId,
    required String btId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.lengthInBytes > AppConfig.maxResumeSizeBytes) {
      throw Exception('File exceeds the 2MB size limit.');
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      throw Exception('Only PDF files are supported.');
    }

    final apiClient = _ref.read(apiClientProvider);

    // Phase 1: Request Upload URL
    final phase1Data = await apiClient.post(
      '/storage/upload-url',
      body: {
        "filename": fileName,
        "mime_type": "application/pdf",
        "size_bytes": bytes.lengthInBytes,
        "file_type": "resume",
        "is_profile_file": true
      },
    );
    final fileId = phase1Data['file_id'] as String;
    final uploadUrl = phase1Data['upload_url'] as String;

    // Phase 2: Complete Upload to R2 directly via PUT
    final phase2Res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'application/pdf'},
      body: bytes,
    );

    if (phase2Res.statusCode != 200 && phase2Res.statusCode != 201) {
      throw Exception('Failed to upload file to storage bucket.');
    }

    // Phase 3: Notify Backend to complete upload
    final phase3Data = await apiClient.post(
      '/storage/complete-upload',
      body: {
        "file_id": fileId,
      },
    );

    return StudentFile.fromJson(phase3Data['file']);
  }

  Future<void> deleteResume(String fileId) async {
    final apiClient = _ref.read(apiClientProvider);
    await apiClient.delete('/storage/files/$fileId');
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref);
});
