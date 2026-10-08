import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_field_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: profileState.when(
          loading: () => const AppLoader(),
          error: (error, _) => AppErrorView(
            message: ErrorHelper.getPolishedMessage(error),
            onRetry: () =>
                ref.read(profileControllerProvider.notifier).refresh(),
          ),
          data: (profile) => Column(
            children: [
              // Top Bar with clean Dribbble controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Container(
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
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _confirmSignOut(context, ref),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        tooltip: 'Sign Out',
                      ),
                    ),
                  ],
                ),
              ),

              // Avatar & Profile Info (Matching Dribbble Shot 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A1668FE),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AppAvatar(
                        imageUrl: profile.avatarUrl,
                        name: profile.fullName,
                        size: 78,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${profile.btId} • ${profile.email}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Twin Stats Cards (Matching Dribbble My ranking / My points)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06111827),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_graph_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CGPA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    profile.cgpa.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06111827),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.secondary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Backlogs',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${profile.activeBacklogs} Active',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Academic & Contact Details
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    ProfileFieldCard(label: 'Branch', value: profile.branch),
                    ProfileFieldCard(
                      label: 'Backlogs History',
                      value: '${profile.backlogs} total (${profile.activeBacklogs} active)',
                    ),
                    ProfileFieldCard(
                      label: 'Education Gaps',
                      value: '${profile.educationGaps} years',
                    ),
                    ProfileFieldCard(
                      label: 'Phone Number',
                      value: profile.phoneNumber,
                    ),
                    ProfileFieldCard(
                      label: 'College Number',
                      value: profile.collegeNumber,
                    ),
                    const SizedBox(height: 8),
                    // Orange CTA Edit Button
                    AppButton(
                      label: AppStrings.editProfile,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.edit_rounded,
                      onPressed: () =>
                          context.pushNamed(RouteNames.editProfile),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Sign out?',
      message:
          "You'll need to sign in again to access your placement dashboard.",
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (confirmed) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}
