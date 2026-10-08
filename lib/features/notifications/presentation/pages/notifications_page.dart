import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/notification_model.dart';
import '../controllers/notification_controller.dart';
import '../widgets/notification_card.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: AppStrings.notifications),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(notificationControllerProvider.notifier).refresh(),
        child: notificationsState.when(
          loading: () => const AppLoader(),
          error: (error, _) => AppErrorView(
            message: ErrorHelper.getPolishedMessage(error),
            onRetry: () =>
                ref.read(notificationControllerProvider.notifier).refresh(),
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  AppEmptyState(
                    icon: Icons.notifications_none_rounded,
                    message: AppStrings.noNotificationsMessage,
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationCard(
                  notification: notification,
                  onTap: () {
                    ref
                        .read(notificationControllerProvider.notifier)
                        .markAsRead(notification.id);
                    if (notification.type == NotificationType.roundReminder ||
                        notification.type == NotificationType.application ||
                        notification.type == NotificationType.interview) {
                      context.pushNamed(RouteNames.tracker);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
