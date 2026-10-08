import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._ref);

  final Ref _ref;

  Future<void> createDrive(Map<String, dynamic> payload) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/admin/drives', body: payload);
  }

  Future<Map<String, dynamic>> parseCsvColumns({
    required List<int> fileBytes,
    required String filename,
  }) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.postMultipart(
      '/api/admin/drives/parse-csv-columns',
      fileBytes: fileBytes,
      filename: filename,
      fileField: 'file',
    );
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getDrives() async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/admin/drives');
    return res['drives'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getDriveAnalytics(String driveId) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/admin/drives/$driveId/analytics');
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getApplicants({
    String? jobId,
    String? companyName,
    List<String>? companyNames,
    List<String>? jobIds,
    String? roleTitle,
    String? branch,
  }) async {
    final client = _ref.read(apiClientProvider);

    // Construct query parameters
    final queryParams = <String>[];
    if (jobId != null && jobId.isNotEmpty) {
      queryParams.add('job_id=$jobId');
    }
    if (jobIds != null && jobIds.isNotEmpty) {
      queryParams.add('job_id=${jobIds.join(',')}');
    }
    if (companyName != null && companyName.isNotEmpty) {
      queryParams.add('company_name=${Uri.encodeComponent(companyName)}');
    }
    if (companyNames != null && companyNames.isNotEmpty) {
      queryParams.add('company_name=${Uri.encodeComponent(companyNames.join(','))}');
    }
    if (roleTitle != null && roleTitle.isNotEmpty) {
      queryParams.add('role_title=${Uri.encodeComponent(roleTitle)}');
    }
    if (branch != null && branch.isNotEmpty) {
      queryParams.add('branch=${Uri.encodeComponent(branch)}');
    }

    final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final res = await client.get('/api/admin/applicants$queryStr');
    return res['applicants'] as List<dynamic>? ?? [];
  }

  Future<void> updateApplicantStatus(
    String applicationId,
    String status, {
    String? remarks,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.put(
      '/api/admin/applicants/$applicationId/status',
      body: {'status': status, if (remarks != null) 'remarks': remarks},
    );
  }

  Future<void> sendDeadlineReminders() async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/admin/drives/send-reminders');
  }

  Future<List<dynamic>> getActiveStudents() async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/admin/active-students');
    return res['students'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getAdminLogs({int limit = 10, int offset = 0}) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/admin/logs?limit=$limit&offset=$offset');
    if (kDebugMode) {
      print(res);
    }
    return res['logs'] as List<dynamic>? ?? [];
  }

  Future<void> createAdminLog(Map<String, dynamic> payload) async {
    final client = _ref.read(apiClientProvider);
    if (kDebugMode) {
      print('Creating AdminLog: $payload');
    }
    final res = await client.post('/api/admin/logs', body: payload);
    if (kDebugMode) {
      print('AdminLog Created Response: $res');
    }
  }

  Future<List<dynamic>> getDriveRounds(String driveId) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get('/api/admin/drives/$driveId/rounds');
    return res['rounds'] as List<dynamic>? ?? [];
  }

  Future<void> createDriveRound(
    String driveId,
    Map<String, dynamic> payload,
  ) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/admin/drives/$driveId/rounds', body: payload);
  }

  Future<void> deleteDriveRound(String driveId, String roundId) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/api/admin/drives/$driveId/rounds/$roundId');
  }

  Future<void> updateDriveRound(
    String driveId,
    String roundId,
    Map<String, dynamic> payload,
  ) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/api/admin/drives/$driveId/rounds/$roundId', body: payload);
  }


  Future<Map<String, dynamic>> bulkUploadRoundStatus(
    String driveId,
    String roundId,
    String csvData,
  ) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.postMultipart(
      '/api/admin/drives/$driveId/rounds/$roundId/bulk-status-csv',
      fileBytes: utf8.encode(csvData),
      filename: 'status.csv',
      fileField: 'file',
    );
    return (res as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> getRoundCandidates(
    String driveId,
    String roundId,
  ) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.get(
      '/api/admin/drives/$driveId/rounds/$roundId/candidates',
    );
    if (res != null && res['candidates'] != null) {
      return res['candidates'] as List<dynamic>;
    }
    return [];
  }

  Future<void> updateRoundCandidateStatus(
    String driveId,
    String roundId,
    String studentId, {
    required String status,
    String? remarks,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.put(
      '/api/admin/drives/$driveId/rounds/$roundId/candidates/$studentId',
      body: {
        'status': status,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
  }

  Uri getRoundCandidatesCsvTemplateUri(
    String driveId,
    String roundId, {
    String? token,
  }) {
    final query = token != null && token.isNotEmpty ? '?token=$token' : '';
    return Uri.parse(
      '${AppConfig.backendApiUrl}/api/admin/drives/$driveId/rounds/$roundId/candidates/csv-template$query',
    );
  }

  Uri getApplicantsCsvExportUri({
    String? driveId,
    String? studentName,
    String? btId,
    double? minCgpa,
    String? status,
  }) {
    final queryParams = <String, String>{};
    if (studentName != null && studentName.trim().isNotEmpty) {
      queryParams['student_name'] = studentName.trim();
    }
    if (btId != null && btId.trim().isNotEmpty) {
      queryParams['bt_id'] = btId.trim();
    }
    if (minCgpa != null && minCgpa > 0.0) {
      queryParams['min_cgpa'] = minCgpa.toString();
    }
    if (status != null &&
        status.trim().isNotEmpty &&
        status.toLowerCase() != 'all') {
      queryParams['status'] = status.toLowerCase();
    }

    final path = (driveId != null && driveId.isNotEmpty && driveId != 'ALL')
        ? '/api/admin/drives/$driveId/export'
        : '/api/admin/applicants/export';

    return Uri.parse('${AppConfig.backendApiUrl}$path').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Uri getDriveResumesZipUri(String driveId, {String? token}) {
    final query = token != null && token.isNotEmpty ? '?token=$token' : '';
    return Uri.parse('${AppConfig.backendApiUrl}/api/admin/drives/$driveId/resumes/zip$query');
  }

  Future<List<int>> downloadDriveResumesZip(String driveId) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.getRaw('/api/admin/drives/$driveId/resumes/zip');
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> sendRoundReminders(
    String driveId,
    String roundId,
  ) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.post(
      '/api/admin/drives/$driveId/rounds/$roundId/send-reminders',
    );
    return res as Map<String, dynamic>;
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref),
);
