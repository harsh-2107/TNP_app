import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single shared [SupabaseClient] instance, exposed via Riverpod so every
/// repository injects the same client instead of calling
/// `Supabase.instance.client` directly (keeps repositories testable /
/// mockable).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Live auth-state stream (SIGNED_IN / SIGNED_OUT / TOKEN_REFRESHED / …).
/// Used by [authControllerProvider] and the router redirect logic.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
