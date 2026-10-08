class AdminLog {
  final String id;
  final String adminId;
  final String? adminEmail;
  final String? adminName;
  final String action;
  final String? targetId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AdminLog({
    required this.id,
    required this.adminId,
    this.adminEmail,
    this.adminName,
    required this.action,
    this.targetId,
    required this.details,
    required this.createdAt,
  });

  factory AdminLog.fromJson(Map<String, dynamic> json) {
    return AdminLog(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      adminEmail: json['admin_email'] as String?,
      adminName: json['admin_name'] as String?,
      action: json['action'] as String,
      targetId: json['target_id'] as String?,
      details: json['details'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
