import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/student_profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._ref);

  final Ref _ref;

  Future<StudentProfile> fetchProfile(String userId) async {
    final client = _ref.read(apiClientProvider);
    try {
      final response = await client.get('/api/students/profile');
      if (response != null && response['profile'] != null) {
        return StudentProfile.fromJson(response['profile']);
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    // Return empty profile if fetch fails (e.g. not found)
    return StudentProfile(
      userId: userId,
      fullName: '',
      email: '',
      btId: '',
      branch: '',
      cgpa: 0.0,
      backlogs: 0,
      activeBacklogs: 0,
      educationGaps: 0,
      phoneNumber: '',
      collegeNumber: '',
    );
  }

  Future<StudentProfile> updateProfile(StudentProfile profile) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.patch(
      '/api/students/profile',
      body: profile.toJson(),
    );
    return StudentProfile.fromJson(response['profile']);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref),
);
