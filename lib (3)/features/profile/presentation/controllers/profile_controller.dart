import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/profile_repository.dart';
import '../../domain/student_profile_model.dart';

class ProfileController extends AsyncNotifier<StudentProfile> {
  late ProfileRepository _repository;

  @override
  Future<StudentProfile> build() async {
    _repository = ref.watch(profileRepositoryProvider);
    final user = ref.watch(authControllerProvider).value;
    if (user == null) {
      throw StateError(
        'ProfileController.build() called without a signed-in user.',
      );
    }
    return _repository.fetchProfile(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<bool> save({
    required String fullName,
    required String phoneNumber,
  }) async {
    final current = state.value;
    if (current == null) return false;

    final updated = current.copyWith(
      fullName: fullName,
      phoneNumber: phoneNumber,
    );

    state = const AsyncLoading<StudentProfile>().copyWithPrevious(state);
    final result = await AsyncValue.guard(
      () => _repository.updateProfile(updated),
    );
    state = result;
    return !result.hasError;
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, StudentProfile>(
      ProfileController.new,
    );
