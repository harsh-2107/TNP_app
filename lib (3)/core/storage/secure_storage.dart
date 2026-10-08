import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around [FlutterSecureStorage] for anything that must not
/// live in plain SharedPreferences (cached tokens, last-known-user id).
/// Supabase itself persists its session securely; this is for
/// app-specific secrets only.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kOnboardingSeenKey = 'onboarding_seen';
  static const _kLastUserIdKey = 'last_user_id';

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clearAll() => _storage.deleteAll();

  Future<bool> get hasSeenOnboarding async =>
      (await read(_kOnboardingSeenKey)) == 'true';

  Future<void> setOnboardingSeen() => write(_kOnboardingSeenKey, 'true');

  Future<String?> get lastUserId => read(_kLastUserIdKey);

  Future<void> setLastUserId(String id) => write(_kLastUserIdKey, id);
}

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(const FlutterSecureStorage());
});
