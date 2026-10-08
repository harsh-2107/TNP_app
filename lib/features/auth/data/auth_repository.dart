import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../domain/user_model.dart';

/// Thin translation layer between [AuthService] (Supabase/Google SDK
/// calls, throws raw Exceptions) and the presentation layer (works with
/// [AppUser]).
class AuthRepository {
  AuthRepository(this._authService);

  final AuthService _authService;

  AppUser? get currentUser {
    final user = _authService.currentUser;
    return user == null ? null : AppUser.fromSupabase(user);
  }

  bool get isSignedIn => _authService.isSignedIn;

  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final response = await _authService.signInWithEmail(email: email, password: password);
    final user = response.user;
    if (user == null) throw Exception('Sign-in failed.');
    return AppUser.fromSupabase(user);
  }

  Future<AppUser> signInWithGoogle() async {
    final response = await _authService.signInWithGoogle();
    final user = response.user;
    if (user == null) throw Exception('Sign-in failed.');
    return AppUser.fromSupabase(user);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});
