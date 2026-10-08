import 'package:flutter/material.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification, this.onTap});

  final StudentNotification notification;
  final VoidCallback? onTap;

  IconData get _icon => switch (notification.type) {
        NotificationType.jobOpening => Icons.work_rounded,
        NotificationType.interview => Icons.event_available_rounded,
        NotificationType.application => Icons.check_circle_rounded,
        NotificationType.tip => Icons.lightbulb_rounded,
        NotificationType.general => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: const BoxDecoration(color: AppColors.surfaceSuccess, shape: BoxShape.circle),
              child: Icon(_icon, size: 16, color: AppColors.primary),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          height: 8,
                          width: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.content,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification.createdAt.timeAgo,
                    style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
