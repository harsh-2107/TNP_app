import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:place_row/core/theme/app_radius.dart';

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.xl),
                    bottomRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => _confirmSignOut(context, ref),
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    AppAvatar(
                      imageUrl: profile.avatarUrl,
                      name: profile.fullName,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    ProfileFieldCard(label: 'BT ID', value: profile.btId),
                    ProfileFieldCard(label: 'Branch', value: profile.branch),
                    ProfileFieldCard(
                      label: AppStrings.cgpa,
                      value: profile.cgpa.toStringAsFixed(1),
                    ),
                    ProfileFieldCard(
                      label: 'Backlogs',
                      value: profile.backlogs.toString(),
                    ),
                    ProfileFieldCard(
                      label: 'Active Backlogs',
                      value: profile.activeBacklogs.toString(),
                    ),
                    ProfileFieldCard(
                      label: 'Education Gaps',
                      value: profile.educationGaps.toString(),
                    ),
                    ProfileFieldCard(
                      label: 'Phone Number',
                      value: profile.phoneNumber,
                    ),
                    ProfileFieldCard(
                      label: 'College Number',
                      value: profile.collegeNumber,
                    ),
                    const SizedBox(height: 6),
                    AppButton(
                      label: AppStrings.editProfile,
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
