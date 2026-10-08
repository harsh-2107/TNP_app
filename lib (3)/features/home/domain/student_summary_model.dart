/// The small "CGPA / Current Year" summary strip shown under the Home
/// header. Kept separate from the full [StudentProfile] model (in the
/// profile feature) since Home only ever needs these two fields.
class StudentSummary {
  const StudentSummary({required this.firstName, required this.cgpa, required this.branch});

  final String firstName;
  final double cgpa;
  final String branch;

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      firstName: (json['full_name'] as String?)?.split(' ').first ?? 'Student',
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 0,
      branch: json['branch'] as String? ?? '',
    );
  }
}
