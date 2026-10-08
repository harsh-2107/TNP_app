import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_model.dart';

class NotificationController extends AsyncNotifier<List<StudentNotification>> {
  late NotificationRepository _repository;

  @override
  Future<List<StudentNotification>> build() async {
    _repository = ref.watch(notificationRepositoryProvider);
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return [];
    return _repository.fetchNotifications(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> markAsRead(String id) async {
    final current = state.value;
    if (current == null) return;

    // Optimistic update.
    state = AsyncData([
      for (final n in current)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);

    try {
      await _repository.markAsRead(id);
    } catch (_) {
      // Revert on failure.
      state = AsyncData(current);
    }
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<StudentNotification>>(
  NotificationController.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationControllerProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});
