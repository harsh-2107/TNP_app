enum NotificationType { jobOpening, interview, application, tip, general, roundReminder }

class StudentNotification {
  const StudentNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;

  StudentNotification copyWith({bool? isRead}) => StudentNotification(
        id: id,
        title: title,
        content: content,
        createdAt: createdAt,
        type: type,
        isRead: isRead ?? this.isRead,
      );

  factory StudentNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return StudentNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      type: NotificationType.values.firstWhere(
        (t) => t.name == rawType || (rawType == 'round_reminder' && t == NotificationType.roundReminder),
        orElse: () => NotificationType.general,
      ),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
