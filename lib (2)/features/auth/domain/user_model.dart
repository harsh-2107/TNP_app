/// Domain-level representation of the signed-in user — deliberately
/// smaller than the full Supabase [User] object, exposing only what the
/// presentation layer needs.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.emailVerified = false,
    this.isAdmin = false,
    this.isSuperadmin = false,
  });

  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final bool emailVerified;
  final bool isAdmin;
  final bool isSuperadmin;

  factory AppUser.fromSupabase(dynamic supabaseUser, {bool isAdmin = false, bool isSuperadmin = false}) {
    final metadata = (supabaseUser.userMetadata ?? {}) as Map<String, dynamic>;
    return AppUser(
      id: supabaseUser.id as String,
      email: supabaseUser.email as String? ?? '',
      name: metadata['full_name'] as String? ?? metadata['name'] as String?,
      avatarUrl: metadata['avatar_url'] as String?,
      emailVerified: supabaseUser.emailConfirmedAt != null,
      isAdmin: isAdmin,
      isSuperadmin: isSuperadmin,
    );
  }
}
