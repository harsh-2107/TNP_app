import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_helper.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';
import '../../../../features/profile/data/profile_repository.dart';

/// Drives the Login screen and the router's auth redirect. Exposes
/// `AsyncValue<AppUser?>` — `null` means "no session", so widgets can
/// distinguish "loading", "signed out" and "signed in" cleanly.
class AuthController extends AsyncNotifier<AppUser?> {
  late AuthRepository _repository;

  @override
  Future<AppUser?> build() async {
    _repository = ref.watch(authRepositoryProvider);

    ref.listen(authStateChangesProvider, (_, __) => ref.invalidateSelf());
    final user = _repository.currentUser;
    if (user != null) {
      try {
        final profileRepo = ref.read(profileRepositoryProvider);
        final profile = await profileRepo.fetchProfile(user.id);
        return AppUser(
          id: user.id,
          email: user.email,
          name: user.name,
          avatarUrl: user.avatarUrl,
          emailVerified: user.emailVerified,
          isAdmin: profile.isAdmin,
          isSuperadmin: profile.isSuperadmin,
        );
      } catch (_) {
        return user;
      }
    }
    return null;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await _repository.signInWithGoogle();
      } catch (e, st) {
        print('Google Sign-In Error: $e\n$st');
        rethrow;
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repository.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(ErrorHelper.getPolishedMessage(e), st);
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).value != null;
});
