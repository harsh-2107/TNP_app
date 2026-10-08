import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/student_profile_model.dart';
import '../controllers/profile_controller.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  bool _initialized = false;

  void _initControllers(StudentProfile profile) {
    if (_initialized) return;
    _nameController = TextEditingController(text: profile.fullName);
    _phoneController = TextEditingController(text: profile.phoneNumber);
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameController.dispose();
      _phoneController.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final success = await ref.read(profileControllerProvider.notifier).save(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Edit Profile'),
      body: profileState.when(
        loading: () => const AppLoader(),
        error: (error, _) => const AppLoader(),
        data: (profile) {
          _initControllers(profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                AppTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  isRequired: true,
                  validator: (v) => Validators.required(v, field: 'Full name'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  isRequired: true,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 24),
                AppButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _isSaving ? null : _submit),
              ],
            ),
          );
        },
      ),
    );
  }
}
