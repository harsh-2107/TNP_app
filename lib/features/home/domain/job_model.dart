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
    this.isJob = true,
    this.descriptionSections = const [],
    this.rounds = const [],
    this.jobDescription = '',
    this.expectedPackage = '',
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
  final List<dynamic> descriptionSections;
  final List<dynamic> rounds;
  final String jobDescription;
  final String expectedPackage;

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
      'has_applied',
      'description_sections',
      'rounds',
      'job_description',
      'expected_package',
      'application_deadline',
    };

    final raw = (json['raw_csv_data'] is Map)
        ? json['raw_csv_data'] as Map<String, dynamic>
        : <String, dynamic>{};

    for (final entry in json.entries) {
      if (!ignoredKeys.contains(entry.key) && entry.value != null) {
        if (entry.value is List && (entry.value as List).isEmpty) continue;
        extraData[entry.key] = entry.value;
      }
    }

    for (final entry in raw.entries) {
      if (!ignoredKeys.contains(entry.key) &&
          entry.value != null &&
          entry.value.toString().isNotEmpty) {
        extraData[entry.key] = entry.value;
      }
    }

    final descSections = (json['description_sections'] as List<dynamic>?) ??
        (raw['description_sections'] as List<dynamic>?) ??
        const [];

    final driveRounds = (json['rounds'] as List<dynamic>?) ??
        (raw['rounds'] as List<dynamic>?) ??
        const [];

    final jDesc = (json['job_description'] as String?) ??
        (raw['job_description'] as String?) ??
        '';

    final expPkg = (json['expected_package'] as String?) ??
        (raw['expected_package'] as String?) ??
        '';

    final deadlineStr = (json['application_deadline'] ?? raw['application_deadline']) as String?;

    return CompanyDrive(
      id: json['id'] as String,
      isJob: json['is_job'] as bool? ?? true,
      companyName: json['company_name'] as String? ?? '',
      roleTitle: (json['job_title'] ?? json['role_title']) as String? ?? '',
      eligibilityRules: json['eligibility_rules'] as Map<String, dynamic>? ?? {},
      rawCsvData: extraData,
      status: json['status'] as String? ?? 'open',
      hasApplied: json['has_applied'] as bool? ?? false,
      applicationDeadline: deadlineStr != null ? DateTime.tryParse(deadlineStr) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      descriptionSections: descSections,
      rounds: driveRounds,
      jobDescription: jDesc,
      expectedPackage: expPkg,
    );
  }
}
