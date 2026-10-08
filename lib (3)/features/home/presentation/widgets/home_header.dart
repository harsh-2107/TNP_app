import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../domain/student_summary_model.dart';

/// Gradient header with greeting, notification/profile icon buttons, and
/// the CGPA/Current-Year summary strip.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greetingName,
    required this.summary,
    required this.onNotificationsTap,
    required this.onProfileTap,
    this.unreadNotifications = 0,
  });

  final String greetingName;
  final StudentSummary? summary;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Hello, $greetingName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  AppIconButton(
                    icon: Icons.notifications_rounded,
                    onPressed: onNotificationsTap,
                    badgeCount: unreadNotifications,
                  ),
                  const SizedBox(width: 10),
                  AppIconButton(
                    icon: Icons.person_rounded,
                    onPressed: onProfileTap,
                  ),
                ],
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSuccessAlt,
                border: Border.all(color: AppColors.borderSuccessAlt),
                borderRadius: BorderRadius.circular(0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: 'CGPA',
                      value: summary!.cgpa.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _SummaryItem(
                      label: 'Branch',
                      value: summary!.branch,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.successDark,
          ),
        ),
      ],
    );
  }
}
