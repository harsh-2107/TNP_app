import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_row/core/widgets/app_card.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next case AsyncError(:final error)) {
        final message = ErrorHelper.getPolishedMessage(error);
        context.showSnackBar(message, isError: true);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Header Brand Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A111827),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 32,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      AppStrings.appName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Central Illustration Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A111827),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Graphic Card Avatar / Icon
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Image.asset(
                        'assets/logo2.png',
                        height: 100,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Dribbble Headline
                    const Text(
                      'Placements made Easy!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dribbble Subtitle
                    const Text(
                      'Stay up to date with company news and events, manage campus recruitment drives and jumpstart your career.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Vibrant Orange CTA Button (Matching Dribbble "Get Started" button)
                    AppButton(
                      label: AppStrings.continueWithGoogle,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.g_mobiledata_rounded,
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle(),
                    ),
                    const SizedBox(height: 16),

                    // Subtitle Note
                    const Text(
                      AppStrings.authHelperText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
