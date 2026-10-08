import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/resume_model.dart';
import '../controllers/resume_controller.dart';

/// "Create New Resume" form: resume-type picker, personal details,
/// skills/experience, and per-role visibility toggles.
class CreateResumePage extends ConsumerStatefulWidget {
  const CreateResumePage({super.key});

  @override
  ConsumerState<CreateResumePage> createState() => _CreateResumePageState();
}

class _CreateResumePageState extends ConsumerState<CreateResumePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _skillsController = TextEditingController();
  final _experienceController = TextEditingController();


  bool _prefilledFromAuth = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _prefillFromUser() {
    if (_prefilledFromAuth) return;
    final user = ref.read(authControllerProvider).value;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _emailController.text = user.email;
    }
    _prefilledFromAuth = true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = ResumeFormData(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      technicalSkills: _skillsController.text.trim(),
      experience: _experienceController.text.trim().isEmpty
          ? null
          : _experienceController.text.trim(),
    );

    final success = await ref
        .read(createResumeControllerProvider.notifier)
        .submit(data);
    if (!mounted) return;

    if (success) {
      context.showSnackBar('Resume created successfully.');
      Navigator.of(context).maybePop();
    } else {
      final error = ref.read(createResumeControllerProvider).error;
      final message = ErrorHelper.getPolishedMessage(
        error ?? Exception('Unknown error'),
      );
      context.showSnackBar(message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefillFromUser();
    final isSubmitting = ref.watch(createResumeControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: AppStrings.createNewResume),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AppTextField(
              label: 'Full Name',
              hint: 'Enter your full name',
              controller: _nameController,
              isRequired: true,
              validator: (v) => Validators.required(v, field: 'Full name'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email Address',
              hint: 'your.email@iiitn.ac.in',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              isRequired: true,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Phone Number',
              hint: '+91 98765 43210',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              isRequired: true,
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            AppTextArea(
              label: 'Technical Skills',
              hint: 'Python, Java, Machine Learning, Web Development, etc.',
              controller: _skillsController,
              isRequired: true,
              validator: (v) =>
                  Validators.required(v, field: 'Technical skills'),
            ),
            const SizedBox(height: 16),
            AppTextArea(
              label: 'Work Experience & Projects',
              hint:
                  'Describe your internships, projects, and relevant experience',
              controller: _experienceController,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: AppStrings.createAndSaveResume,
              icon: Icons.save_rounded,
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : _submit,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


