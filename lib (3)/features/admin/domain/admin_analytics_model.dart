import 'dart:math';

class AdminAnalyticsModel {
  final String driveId;
  final String companyName;
  final String roleTitle;
  final int totalStudents;
  final int eligibleStudents;
  final int ineligibleStudents;
  final int appliedOutOfEligible;
  final int unappliedButEligible;
  final int rejectedButEligible;

  const AdminAnalyticsModel({
    required this.driveId,
    required this.companyName,
    required this.roleTitle,
    required this.totalStudents,
    required this.eligibleStudents,
    required this.ineligibleStudents,
    required this.appliedOutOfEligible,
    required this.unappliedButEligible,
    required this.rejectedButEligible,
  });

  factory AdminAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final analytics = json['analytics'] as Map<String, dynamic>? ?? {};
    return AdminAnalyticsModel(
      driveId: json['drive_id'] ?? '',
      companyName: json['company_name'] ?? 'Unknown Company',
      roleTitle: json['role_title'] ?? 'Unknown Role',
      totalStudents: analytics['total_students'] ?? 0,
      eligibleStudents: analytics['eligible_students'] ?? 0,
      ineligibleStudents: analytics['ineligible_students'] ?? 0,
      appliedOutOfEligible: analytics['applied_out_of_eligible'] ?? 0,
      unappliedButEligible: analytics['unapplied_but_eligible'] ?? 0,
      rejectedButEligible: analytics['rejected_but_eligible'] ?? 0,
    );
  }

  // Create an empty instance for cumulative sums or when there are no drives
  factory AdminAnalyticsModel.empty() {
    return const AdminAnalyticsModel(
      driveId: 'cumulative',
      companyName: 'All Drives',
      roleTitle: 'Cumulative',
      totalStudents: 0,
      eligibleStudents: 0,
      ineligibleStudents: 0,
      appliedOutOfEligible: 0,
      unappliedButEligible: 0,
      rejectedButEligible: 0,
    );
  }

  // Helper method to add two analytics models together (for cumulative)
  AdminAnalyticsModel operator +(AdminAnalyticsModel other) {
    return AdminAnalyticsModel(
      driveId: 'cumulative',
      companyName: 'All Drives',
      roleTitle: 'Cumulative',
      // Total students is consistent across drives, so we take the max to avoid inflating the number
      totalStudents: max(totalStudents, other.totalStudents),
      eligibleStudents: eligibleStudents + other.eligibleStudents,
      ineligibleStudents: ineligibleStudents + other.ineligibleStudents,
      appliedOutOfEligible: appliedOutOfEligible + other.appliedOutOfEligible,
      unappliedButEligible: unappliedButEligible + other.unappliedButEligible,
      rejectedButEligible: rejectedButEligible + other.rejectedButEligible,
    );
  }
}
