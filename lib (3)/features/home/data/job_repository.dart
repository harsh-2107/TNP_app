import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/job_model.dart';
import '../domain/student_summary_model.dart';

/// Data source for the Home feed: active opportunities + the student's
/// summary strip. Backed by Supabase tables `jobs` and `students`.
class JobRepository {
  JobRepository(this._ref);

  final Ref _ref;

  Future<List<CompanyDrive>> fetchActiveOpportunities() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/api/students/jobs');
    if (kDebugMode) {
      print(response);
    }
    if (response != null && response['jobs'] != null) {
      final List jobs = response['jobs'];
      final drives = jobs
          .map((row) => CompanyDrive.fromJson(row as Map<String, dynamic>))
          .toList();
      drives.sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return drives;
    }
    return [];
  }

  Future<Map<String, dynamic>> checkDriveRequirements({
    required String jobId,
    required String studentId,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get(
      '/api/applications/check-requirements/$jobId?student_id=$studentId',
    );
    if (response != null && response is Map<String, dynamic>) {
      return response;
    }
    return {
      'is_primary_eligible': true,
      'requires_additional_info': false,
      'missing_fields': [],
    };
  }

  Future<void> applyToJob({
    required String studentId,
    required String jobId,
    String? resumeFileId,
    Map<String, dynamic>? customFields,
  }) async {
    final client = _ref.read(apiClientProvider);
    final body = <String, dynamic>{'student_id': studentId, 'job_id': jobId};
    if (resumeFileId != null) {
      body['resume_file_id'] = resumeFileId;
    }
    if (customFields != null && customFields.isNotEmpty) {
      body['custom_fields'] = customFields;
    }
    await client.post('/api/applications/apply', body: body);
  }

  Future<void> rejectJob({
    required String studentId,
    required String jobId,
  }) async {
    final client = _ref.read(apiClientProvider);
    final body = {'student_id': studentId, 'job_id': jobId};
    await client.post('/api/applications/reject', body: body);
  }

  Future<StudentSummary> fetchStudentSummary(String userId) async {
    final client = _ref.read(apiClientProvider);
    try {
      final response = await client.get('/api/students/profile');
      if (response != null && response['profile'] != null) {
        return StudentSummary.fromJson(response['profile']);
      }
    } catch (_) {}
    return const StudentSummary(firstName: 'Student', cgpa: 0.0, branch: '');
  }

  Future<List<dynamic>> getMyRounds() async {
    final client = _ref.read(apiClientProvider);
    try {
      final res = await client.get('/api/students/my-rounds');
      if (res != null && res['my_drives'] != null) {
        return res['my_drives'] as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching my-rounds: $e');
    }
    return [];
  }

  Future<List<dynamic>> getDriveRoundsStatus(String driveId) async {
    final client = _ref.read(apiClientProvider);
    try {
      final res = await client.get(
        '/api/students/drives/$driveId/rounds-status',
      );
      if (kDebugMode) print('getDriveRoundsStatus for $driveId returned: $res');
      if (res != null && res['rounds'] != null) {
        return res['rounds'] as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching drive rounds status: $e');
    }
    return [];
  }
}

final jobRepositoryProvider = Provider<JobRepository>(
  (ref) => JobRepository(ref),
);
