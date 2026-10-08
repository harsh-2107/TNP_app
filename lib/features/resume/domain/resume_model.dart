class StudentFile {
  const StudentFile({
    required this.id,
    required this.studentId,
    required this.objectKey,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileType,
    required this.isProfileFile,
    required this.isDefault,
    required this.usedForApplication,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String objectKey;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String fileType;
  final bool isProfileFile;
  final bool isDefault;
  final bool usedForApplication;
  final DateTime createdAt;

  factory StudentFile.fromJson(Map<String, dynamic> json) {
    return StudentFile(
      id: json['id'] as String,
      studentId: json['student_id'] as String? ?? '',
      objectKey: json['object_key'] as String? ?? '',
      filename: json['filename'] as String? ?? 'resume.pdf',
      mimeType: json['mime_type'] as String? ?? 'application/pdf',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      fileType: json['file_type'] as String? ?? 'resume',
      isProfileFile: json['is_profile_file'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      usedForApplication: json['used_for_application'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// The "Create New Resume" form payload.
class ResumeFormData {
  const ResumeFormData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.technicalSkills,
    this.experience,
  });

  final String fullName;
  final String email;
  final String phone;
  final String technicalSkills;
  final String? experience;

  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'technical_skills': technicalSkills,
      'experience': experience,
    };
  }
}
