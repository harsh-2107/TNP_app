import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/notification_model.dart';

class NotificationRepository {
  NotificationRepository(this._ref);

  final Ref _ref;

  Future<List<StudentNotification>> fetchNotifications(String userId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/api/students/notifications');
    if (response != null && response['notifications'] != null) {
      final List notifications = response['notifications'];
      return notifications
          .map((row) => StudentNotification.fromJson(row as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> markAsRead(String notificationId) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/api/students/notifications/$notificationId/read');
  }
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref));
