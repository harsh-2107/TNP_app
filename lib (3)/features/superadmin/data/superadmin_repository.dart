import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class SuperadminRepository {
  SuperadminRepository(this._ref);

  final Ref _ref;

  // --- 1. Analytics & Monitoring ---

  Future<Map<String, dynamic>> getStats() async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/superadmin/stats');
    if (kDebugMode) {
      print(res);
    }
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDatabaseOverview() async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/superadmin/database/overview');
    if (kDebugMode) {
      print('DB_OVERVIEW: $res');
    }
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAuditLogs({int limit = 10, int offset = 0}) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/superadmin/audit-logs?limit=$limit&offset=$offset');
    return res['logs'] as List<dynamic>? ?? [];
  }

  // --- 2. Role Management ---

  Future<List<dynamic>> getAdmins({String? role}) async {
    final client = _ref.read(apiClientProvider);
    final query = (role != null && role.isNotEmpty && role.toLowerCase() != 'all')
        ? '?role=${Uri.encodeComponent(role)}'
        : '';
    final res = await client.get('/api/superadmin/admins$query');
    return res['admins'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getAdminsOverview({String? role}) async {
    final client = _ref.read(apiClientProvider);
    final query = (role != null && role.isNotEmpty && role.toLowerCase() != 'all')
        ? '?role=${Uri.encodeComponent(role)}'
        : '';
    final res = await client.get('/api/superadmin/admins$query');
    return res as Map<String, dynamic>;
  }

  Future<void> assignRole(Map<String, dynamic> payload) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/superadmin/admins/assign-role', body: payload);
  }

  // --- 3. Student Management ---

  Future<List<dynamic>> getStudents() async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/superadmin/students');
    return res['students'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getStudent(String id) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/superadmin/students/$id');
    return res as Map<String, dynamic>;
  }

  Future<void> createStudent(Map<String, dynamic> payload) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/superadmin/students', body: payload);
  }

  Future<void> updateStudent(String id, Map<String, dynamic> payload) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/api/superadmin/students/$id', body: payload);
  }

  Future<void> deleteStudent(String id) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/api/superadmin/students/$id');
  }

  Future<void> batchImportCsv(List<int> fileBytes, String filename) async {
    final client = _ref.read(apiClientProvider);
    await client.postMultipart(
      '/api/superadmin/students/batch-import-csv',
      fileBytes: fileBytes,
      filename: filename,
      fileField: 'file',
    );
  }

  // --- 4. Drives Override ---

  Future<void> updateDrive(String driveId, Map<String, dynamic> payload) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/api/superadmin/drives/$driveId', body: payload);
  }

  Future<void> forceDeleteDrive(String driveId) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/api/superadmin/drives/$driveId');
  }

  Future<void> forceApplyStudentToDrive(
    String driveId,
    String studentId,
  ) async {
    final client = _ref.read(apiClientProvider);
    await client.post(
      '/api/superadmin/drives/$driveId/force-apply',
      body: {'student_id': studentId},
    );
  }

  // --- 5. Applications Override ---

  Future<List<dynamic>> getApplications() async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/superadmin/applications');
    return res['applications'] as List<dynamic>? ?? [];
  }

  Future<void> updateApplication(
    String applicationId,
    Map<String, dynamic> payload,
  ) async {
    final client = _ref.read(apiClientProvider);
    await client.put(
      '/api/superadmin/applications/$applicationId',
      body: payload,
    );
  }

  Future<void> deleteApplication(String applicationId) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/api/superadmin/applications/$applicationId');
  }
}

final superadminRepositoryProvider = Provider<SuperadminRepository>(
  (ref) => SuperadminRepository(ref),
);
