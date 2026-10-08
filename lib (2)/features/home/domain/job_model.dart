class CompanyDrive {
  const CompanyDrive({
    required this.id,
    required this.companyName,
    required this.roleTitle,
    required this.eligibilityRules,
    required this.rawCsvData,
    required this.status,
    this.hasApplied = false,
    this.applicationDeadline,
    this.createdAt,
    this.isJob = true
  });
  final bool isJob;
  final String id;
  final String companyName;
  final String roleTitle;
  final Map<String, dynamic> eligibilityRules;
  final Map<String, dynamic> rawCsvData;
  final String status;
  final bool hasApplied;
  final DateTime? applicationDeadline;
  final DateTime? createdAt;

  factory CompanyDrive.fromJson(Map<String, dynamic> json) {
    final extraData = <String, dynamic>{};
    final ignoredKeys = {
      'id',
      'is_job',
      'company_name',
      'job_title',
      'role_title',
      'status',
      'eligibility_rules',
      'raw_csv_data',
      'created_at',
      'is_eligible',
      'reasons',
      'has_applied'
    };

    for (final entry in json.entries) {
      if (!ignoredKeys.contains(entry.key) && entry.value != null) {
        if (entry.value is List && (entry.value as List).isEmpty) continue;
        extraData[entry.key] = entry.value;
      }
    }

    if (json['raw_csv_data'] is Map) {
      final raw = json['raw_csv_data'] as Map<String, dynamic>;
      for (final entry in raw.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          extraData[entry.key] = entry.value;
        }
      }
    }

    return CompanyDrive(
      id: json['id'] as String,
      isJob: json['is_job'] as bool? ?? true,
      companyName: json['company_name'] as String? ?? '',
      roleTitle: (json['job_title'] ?? json['role_title']) as String? ?? '',
      eligibilityRules: json['eligibility_rules'] as Map<String, dynamic>? ?? {},
      rawCsvData: extraData,
      status: json['status'] as String? ?? 'open',
      hasApplied: json['has_applied'] as bool? ?? false,
      applicationDeadline: json['application_deadline'] != null
          ? DateTime.tryParse(json['application_deadline'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
