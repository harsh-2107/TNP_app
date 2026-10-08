import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_config.dart';
import '../network/supabase_client_provider.dart';

/// Wraps Supabase Auth (email/password) + native Google Sign-In, exposing
/// a small surface. Repositories/controllers should depend on this rather
/// than touching `Supabase.instance.auth` or `GoogleSignIn` directly.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// Completer ensures `GoogleSignIn.instance.initialize()` runs exactly once.
  static Completer<void>? _googleInitCompleter;

  /// Lazily initializes the [GoogleSignIn] singleton the first time a
  /// Google-related method is called.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitCompleter != null) {
      return _googleInitCompleter!.future;
    }
    _googleInitCompleter = Completer<void>();
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      );
      _googleInitCompleter!.complete();
    } catch (e) {
      // Reset so a retry is possible on next call.
      final completer = _googleInitCompleter!;
      _googleInitCompleter = null;
      completer.completeError(e);
      rethrow;
    }
  }

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Native Google sign-in, token-exchanged into a Supabase session.
  Future<AuthResponse> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final googleUser = await GoogleSignIn.instance.authenticate();

    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('Could not retrieve Google ID token.');
    }

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signOut() async {
    await Future.wait([
      _client.auth.signOut(),
      GoogleSignIn.instance.signOut(),
    ]);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});
