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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Greeting & Quick Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $greetingName',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary != null ? '${summary!.branch} • Batch of ${summary!.batchYear}' : 'Placement Portal',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    onPressed: onNotificationsTap,
                    badgeCount: unreadNotifications,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.person_outline_rounded,
                    onPressed: onProfileTap,
                  ),
                ],
              ),
            ],
          ),

          if (summary != null) ...[
            const SizedBox(height: 16),
            // Twin Cards matching Dribbble "Day off" and "Vacation" cards
            Row(
              children: [
                // Card 1: Vibrant Royal Blue Primary Card (CGPA)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x331668FE),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cumulative CGPA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary!.cgpa.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Card 2: Soft White Card (Branch & Active Drives)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A111827),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Registered Branch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary!.branch,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 20, color: AppColors.textPrimary),
            onPressed: onPressed,
          ),
          if (badgeCount > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
