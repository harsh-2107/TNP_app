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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 36),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/logo.png',
                            height: 40,
                            alignment: AlignmentGeometry.centerLeft,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppStrings.appName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),
                    Text(
                      AppStrings.appTagline,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Filler: Welcome text
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 24,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ready to jumpstart your career?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Central Logo
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceMuted,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset('assets/logo.png', height: 100),
                      ),
                      const SizedBox(height: 48),

                      // Google Sign In
                      AppButton(
                        label: AppStrings.continueWithGoogle,
                        variant: AppButtonVariant.google,
                        icon: Icons.g_mobiledata_rounded,
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle(),
                      ),
                      const SizedBox(height: 24),

                      // Helper Text
                      const Text(
                        AppStrings.authHelperText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
