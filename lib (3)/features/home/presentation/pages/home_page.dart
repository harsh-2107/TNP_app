import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../widgets/home_header.dart';
import '../widgets/job_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeControllerProvider);
    final user = ref.watch(authControllerProvider).value;
    final firstName = (user?.name?.split(' ').first) ?? user?.email.split('@').first ?? 'Student';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeHeader(
              greetingName: firstName,
              summary: homeState.value?.summary,
              onNotificationsTap: () => context.pushNamed(RouteNames.notifications),
              onProfileTap: () => context.pushNamed(RouteNames.profile),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
                child: homeState.when(
                  loading: () => const AppLoader(),
                  error: (error, _) => AppErrorView(
                    message: ErrorHelper.getPolishedMessage(error),
                    onRetry: () => ref.read(homeControllerProvider.notifier).refresh(),
                  ),
                  data: (state) {
                    if (state.opportunities.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          AppEmptyState(
                            icon: Icons.work_outline_rounded,
                            message: AppStrings.noOpportunitiesMessage,
                          ),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(18),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const Text(
                          AppStrings.activeOpportunities,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final job in state.opportunities) JobCard(job: job),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
