class StudentProfile {
  const StudentProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.btId,
    required this.branch,
    required this.cgpa,
    required this.backlogs,
    required this.activeBacklogs,
    required this.educationGaps,
    required this.phoneNumber,
    required this.collegeNumber,
    this.lastActiveAt,
    this.avatarUrl,
    this.isAdmin = false,
    this.isSuperadmin = false,
  });

  final String userId;
  final String fullName;
  final String email;
  final String btId;
  final String branch;
  final double cgpa;
  final int backlogs;
  final int activeBacklogs;
  final int educationGaps;
  final String phoneNumber;
  final String collegeNumber;
  final DateTime? lastActiveAt;
  final String? avatarUrl;
  final bool isAdmin;
  final bool isSuperadmin;

  StudentProfile copyWith({
    String? fullName,
    String? phoneNumber,
    String? collegeNumber,
    DateTime? lastActiveAt,
    String? avatarUrl,
    bool? isAdmin,
    bool? isSuperadmin,
  }) {
    return StudentProfile(
      userId: userId,
      fullName: fullName ?? this.fullName,
      email: email,
      btId: btId,
      branch: branch,
      cgpa: cgpa,
      backlogs: backlogs,
      activeBacklogs: activeBacklogs,
      educationGaps: educationGaps,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      collegeNumber: collegeNumber ?? this.collegeNumber,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuperadmin: isSuperadmin ?? this.isSuperadmin,
    );
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      userId: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      btId: json['bt_id'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 0,
      backlogs: (json['backlogs'] as num?)?.toInt() ?? 0,
      activeBacklogs: (json['active_backlogs'] as num?)?.toInt() ?? 0,
      educationGaps: (json['education_gaps'] as num?)?.toInt() ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      collegeNumber: json['college_number'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      isSuperadmin: json['is_superadmin'] as bool? ?? false,
      lastActiveAt: json['last_active_at'] != null 
          ? DateTime.tryParse(json['last_active_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone_number': phoneNumber,
    };
  }
}
